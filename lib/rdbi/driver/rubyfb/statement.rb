require 'rdbi/driver/rubyfb'
require 'rubyfb'
require 'epoxy'

class RDBI::Driver::Rubyfb::Statement < RDBI::Statement
  # FIXME - our autocommit attempt it totally bogus, is it?
  def initialize(query, dbh)
    super(query, dbh)

    @fb_stmt = Rubyfb::Statement.new(dbh.fb_cxn,
                                     dbh.fb_txns[-1],
                                     query,
                                     dbh.fb_dialect)

    @index_map = Epoxy.new(query).indexed_binds
    # @input_type_map initialized in superclass
    @output_type_map = RDBI::Type.create_type_hash(RDBI::Type::Out)
    #puts "Statement.new #{self}"
  end

  def finish
    #puts "finishing #{@fb_stmt}"
    @fb_stmt.close
    super
  end

  def new_modification(*binds)
    new_execution(*binds)
  end

  def new_execution(*binds)
    hashes, binds = binds.partition { |x| x.kind_of?(Hash) }
    hash = hashes.inject({}) { |x, y| x.merge(y) }
    hash.keys.each do |key|
      if index = @index_map.index(key)
        binds.insert(index, hash[key])
      end
    end

    unless @fb_stmt.transaction.active?
      # We've been called and committed/rollbacked before
      # XXX - do we really have to re-prepare for a new TXN?
      @fb_stmt = Rubyfb::Statement.new(dbh.fb_cxn,
                                       Rubyfb::Transaction.new(dbh.fb_cxn),
                                       query,
                                       dbh.fb_dialect)
    end

    #puts "Statement#execute(#{dbh.fb_cxn}, #{@fb_stmt.transaction}, \"#{query}\")"
    result = binds.length > 0 ? @fb_stmt.execute_for(binds) : @fb_stmt.execute

    num_columns = result.column_count rescue 0
    columns = (0...num_columns).collect do |i|
      c = RDBI::Column.new(
                           result.column_alias(i),
                           result.get_base_type(i),
                           result.get_base_type(i), # XXX - some floats BIGINT in IB6
                           0,
                           0
                          )
                          #puts c
                          #c
    end
    cursor = RDBI::Driver::Rubyfb::Cursor.new(result)
    [ cursor, RDBI::Schema.new(columns), @output_type_map ]
  end #-- new_execution

end #-- class Statement
