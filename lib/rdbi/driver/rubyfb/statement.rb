require 'rdbi/driver/rubyfb'
require 'rubyfb'

class RDBI::Driver::Rubyfb::Statement < RDBI::Statement
  # FIXME - our autocommit attempt it totally bogus, is it?
  def initialize(query, dbh)
    super(query, dbh)

    # If we were _not_ created inside a #transaction(&block), we need
    # to fake an auto-commit mode
    if dbh.fb_txns.empty?
      @fake_autocommit = true
      txn = Rubyfb::Transaction.new(dbh.fb_cxn)
    else
      @fake_autocommit = false
      txn = dbh.fb_txns[-1]
    end
    @fb_stmt = Rubyfb::Statement.new(dbh.fb_cxn,
                                     txn,
                                     query,
                                     dbh.fb_dialect)

    @index_map = Epoxy.new(query).indexed_binds
    # @input_type_map initialized in superclass
    @output_type_map = RDBI::Type.create_type_hash(RDBI::Type::Out)

    prep_finalizer {
      @fb_stmt.close rescue nil
    }
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

    if fake_autocommit? and !@fb_stmt.transaction.active?
      # We've been called and committed/rollbacked before
      @fb_stmt = Rubyfb::Statement.new(dbh.fb_cxn,
                                       Rubyfb::Transaction.new(dbh.fb_cxn),
                                       query,
                                       dbh.fb_dialect)
    end

    #puts "===> #{query}"
    result = if fake_autocommit?
               exec_autocommit(binds)
             else
               exec(binds)
             end

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
    [ RDBI::Driver::Rubyfb::Cursor.new(result), RDBI::Schema.new(columns), @output_type_map ]
  end #-- new_execution

  protected
  def fake_autocommit?
    @fake_autocommit
  end

  def exec(parameters)
    if parameters.length > 0
      @fb_stmt.execute_for(parameters)
    else
      @fb_stmt.execute
    end
  end

  def exec_autocommit(parameters)
    if !@fb_stmt.transaction.active?
      # Re-prepare for anonymous transaction
      @fb_stmt = Rubyfb::Statement.new(dbh.fb_cxn,
                                       Rubyfb::Transaction.new(dbh.fb_cxn),
                                       query,
                                       dbh.fb_dialect)
    end
    result = exec(parameters)
    @fb_stmt.transaction.commit
    result
  rescue Rubyfb::FireRubyException => e
    @fb_stmt.transaction.rollback rescue nil
    raise e
  end
end #-- class Statement
