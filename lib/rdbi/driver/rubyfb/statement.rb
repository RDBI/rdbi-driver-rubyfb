require 'rdbi/driver/rubyfb'
require 'typelib'
require 'rubyfb'
require 'date'
require 'epoxy'

#--
# TODO:  Allow changing time zone
#++

class RDBI::Driver::Rubyfb
class Statement < RDBI::Statement
  # Type conversions we perform:
  #
  #   Firebird    Rubyfb     RDBI    Notes
  #   ---------  --------  --------  -------------------------------------
  #   TIMESTAMP      Time  DateTime
  #   TIMESTAMP  DateTime  DateTime  (if out of range of Time)
  #        CHAR     'a   '      'a'
  #
  RTRIM_RE   = ::Regexp.new(/ +\z/)                 # :nodoc:
  TIME_ZONE  = ::DateTime.now.zone                  # :nodoc:
  STR_RTRIM  = proc { |str| str.sub(RTRIM_RE, '') } # :nodoc:
  IS_STR     = proc { |x| x.kind_of?(::String) }    # :nodoc:
  IS_TIME    = proc { |x| x.kind_of?(::Time) }      # :nodoc:
  TIME_TO_DT = proc { |t|                           # :nodoc:
                 ::DateTime.new(t.year,
                                t.month,
                                t.day,
                                t.hour,
                                t.min,
                                t.sec + Rational(t.usec, 10**6),
                                Rational(t.utc_offset, 60 * 60 * 24))
               } # :nodoc:

  OUTPUT_MAP = RDBI::Type.create_type_hash(RDBI::Type::Out).merge({ # :nodoc:
                 :timestamp => [TypeLib::Filter.new(IS_TIME, TIME_TO_DT)],
                 :char      => [TypeLib::Filter.new(IS_STR, STR_RTRIM)]
               }) # :nodoc:

  def initialize(query, dbh, cxn, txn, dialect)
    super(query, dbh)

    ep = Epoxy.new(query)
    @index_map = ep.indexed_binds
    oh_epoxy_could_simplify_this = @index_map.compact.inject({}) {|accum,i| accum.merge({i=>nil})}
    @xlated_query = ep.quote(oh_epoxy_could_simplify_this) {|x| '?'}

    @fb_stmt = Rubyfb::Statement.new(cxn,
                                     txn,
                                     @xlated_query,
                                     dialect)
  end

  def finish
    #puts "finishing #{@fb_stmt}"
    super
    @fb_stmt.close
  end

  def new_modification(*binds)
    result = exec_query(binds)
    return case result
           when ::Numeric
             result
           else # Hmm, a query which did not affect rows was passed to
             0  # #execute_modification() (either Database or Statement).
           end
  end

  def new_execution(*binds)
    result = exec_query(binds)

    num_columns = result.column_count rescue 0
    columns = (0...num_columns).collect do |i|
      base_type = result.get_base_type(i).to_s.downcase.to_sym
      ruby_type = Types::rubyfb_to_rdbi(base_type,
                                        (result.column_scale(i) rescue 0))
      c = RDBI::Column.new(
                           result.column_alias(i).to_sym,
                           base_type,
                           ruby_type,
                           0,
                           0
                          )
                          #puts c
                          #c
    end
    cursor_klass = self.rewindable_result ? ArrayCursor : ForwardOnlyCursor
    [ cursor_klass.new(result), RDBI::Schema.new(columns), OUTPUT_MAP ]
  end #-- new_execution

  private

  # Parse parameters, open a new txn if needed, and return the Rubyfb query
  # result
  def exec_query(binds)
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
      # XXX - this is incorrect, as this TXN cannot be committed/canceled
      cxn, dialect = @fb_stmt.connection, @fb_stmt.dialect
      @fb_stmt.close
      @fb_stmt = Rubyfb::Statement.new(cxn,
                                       Rubyfb::Transaction.new(dbh.fb_cxn),
                                       @xlated_query,
                                       dialect)
    end

    return (binds.length > 0 ? @fb_stmt.execute_for(binds) : @fb_stmt.execute)
  end
end #-- class Statement
end #-- class RDBI::Driver::Rubyfb
