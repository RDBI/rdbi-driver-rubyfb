require 'rdbi/driver/rubyfb'
require 'rubyfb'

class RDBI::Driver::Rubyfb::Database < RDBI::Database

  ##
  #
  #     RDBI.connect(:Rubyfb, :database => db,
  #                           :user     => 'SYSDBA',
  #                           :password => 'masterkey')
  #
  # Connect to the specified database using the specified +:user+ and
  # +:password+ credentials, which credentials, if omitted, default to the
  # environment variables $ISC_USER and $ISC_PASSWORD.
  #
  # +:database+ may be a local filename, influenced by $ISC_DATABASE, a
  # Firebird alias or a remote connection string.  Remote connection strings
  # specify a host optionally followed by a slash ('/') and port, a colon (':')
  # and a database filename or alias.  If omitted, port defaults to 3050
  # (gds_db) or whatever is specified as a default in the local Firebird
  # system configuration.  For example:
  #
  # - <tt>localhost/3050:C:\path\to\database.fdb</tt>
  # - <tt>localhost/gds_db:C:\path\to\database.fdb</tt>
  # - <tt>localhost:C:\path\to\database.fdb</tt>
  # - <tt>localhost:alias-for-database</tt>
  #
  def initialize(*args)
    #--
    # TODO:  allow create database
    #++
    super(*args)
    self.database_name = @connect_args[:database] || @connect_args[:db]
    @fb_db             = Rubyfb::Database.new(self.database_name)
    @fb_dialect        = @connect_args[:dialect] || 3

    user = @connect_args[:user] || @connect_args[:username]
    pass = @connect_args[:password] || @connect_args[:auth]
    @fb_cxn  = @fb_db.connect(user, pass)
    @fb_txns = [Rubyfb::Transaction.new(@fb_cxn)]
  rescue Rubyfb::FireRubyException => e
    raise RDBI::Error.new(e.message)
  end

  # Disconnect
  def disconnect
    # First, let RDBI take care of bookkeeping, which
    # includes explicitly #finish()ing any child sths.
    super
    # Now close the open connection.  If we reversed
    # the order, orphaned child statements would throw
    # errors upon #finish().
    @fb_cxn.close unless @fb_cxn.closed?
  end

  ##
  # Begin a new transaction.
  #
  # Firebird supports nested transactions, but this behavior is not portable
  # across all drivers.
  def transaction(&block)
    @fb_txns << Rubyfb::Transaction.new(@fb_cxn)
    super &block
  end

  def commit
    # FIXME - in_trans? check
    txn = @fb_txns.pop
    begin
      txn.commit
    rescue Rubyfb::FireRubyException
      # E.g. failed DROP TABLE commit, b/c 'object is in use', still
      # referenced by an active DML statement.
      @fb_txns << txn
      raise
    end
    @fb_txns << Rubyfb::Transaction.new(@fb_cxn) if @fb_txns.empty?
    super
  end

  def rollback
    # FIXME - in_trans? check
    txn = @fb_txns.pop
    begin
      txn.rollback
    rescue Rubyfb::FireRubyException
      @fb_txns << txn
    end
    @fb_txns.pop.rollback
    @fb_txns << Rubyfb::Transaction.new(@fb_cxn) if @fb_txns.empty?
    super
  end

  def new_statement(query)
    RDBI::Driver::Rubyfb::Statement.new(query, self, @fb_cxn, @fb_txns[-1], @fb_dialect)
  end

  # Return a true value if the database is still connected, or raise
  # RDBI::DisconnectedError.
  #
  # At present this method returns the time taken to check the connection,
  # however, these semantics are not portable across drivers, and may change
  # within this driver, and so should not be relied upon.
  def ping
    # perl-DBD-InterBase calls isc_database_info(), but rubyfb-0.5.5 does
    # not expose that interface
    t0 = ::Time.now
    @fb_cxn.execute_immediate('SELECT 1 AS PING FROM RDB$DATABASE') do |r|
    end
    t1 = ::Time.now
    t0.to_i - t1.to_i
  rescue Rubyfb::FireRubyException => e
    raise RDBI::DisconnectedError.new(e.message)
  end

  # Return an RDBI::Schema object describing the table or view.
  #
  # +tbl+ is internally normalized to uppercase.  At present, the
  # 'default' member of RDBI::Column is not supported.
  def table_schema(tbl)
    column_sql = <<-eosql
SELECT    rf.rdb$field_name         AS "name",
          field.rdb$field_type      AS "type_code",
          field.rdb$field_sub_type  AS "subtype_code",
-- -- --  field.rdb$field_length    AS "length",  -- -- --
          field.rdb$field_precision AS "precision",
          field.rdb$field_scale     AS "scale",
          CASE
          WHEN rf.rdb$null_flag > 0
            THEN 'NO'
          ELSE   'YES'
          END                       AS "nullable",
          CASE
          WHEN iseg.rdb$index_name IS NOT NULL
            THEN 'YES'
          ELSE   'NO'
          END                       AS "primary_key"
FROM      rdb$relation_fields rf
JOIN      rdb$fields field ON rf.rdb$field_source = field.rdb$field_name
LEFT JOIN rdb$relation_constraints c
            ON c.rdb$relation_name = rf.rdb$relation_name
               AND
               c.rdb$constraint_type = 'PRIMARY KEY'
LEFT JOIN rdb$index_segments iseg
            ON iseg.rdb$index_name = c.rdb$index_name
               AND
               iseg.rdb$field_name = rf.rdb$field_name
WHERE     rf.rdb$relation_name = ?
ORDER BY  rf.rdb$field_position, rf.rdb$field_name
eosql

    info = RDBI::Schema.new([], [])
    res = execute(column_sql, tbl.to_s.upcase)
    res.as(:Struct)
    while row = res.fetch[0]
      type = RDBI::Driver::Rubyfb::Types::field_type_to_rubyfb(row[:type_code], row[:subtype_code])
      info.columns << RDBI::Column.new(
                        row[:name].to_sym,
                        type,
                        RDBI::Driver::Rubyfb::Types::rubyfb_to_rdbi(type, row[:scale]),
                        row[:precision],
                        row[:scale],
                        row[:nullable] == 'YES',
                       #nil, # metadata
                       #nil, # default
                       #nil, # table
                      )
      (info.columns[-1].primary_key = row[:primary_key] == 'YES') rescue nil # pk > rdbi 0.9.1
    end
    return unless info.columns.length > 0
    info.tables << tbl
    info
  end

  # Return a list of RDBI::Schema objects for the current connection,
  # excluding system objects, for example tables beginning with 'RDB$' or
  # 'MON$'.
  def schema
    execute(<<-eosql).collect { |row| row[0] }.collect { |t| table_schema(t) }
SELECT rdb$relation_name FROM rdb$relations WHERE rdb$system_flag != 1
eosql
  end

end # -- class Database
