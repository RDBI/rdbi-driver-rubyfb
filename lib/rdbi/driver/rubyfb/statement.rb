require 'rdbi/driver/rubyfb'
require 'typelib'
require 'rubyfb'
require 'date'
require 'epoxy'

class RDBI::Driver::Rubyfb
class Statement < RDBI::Statement
  # :nodoc:
  # Type conversions we perform:
  #
  #   Firebird    Rubyfb     RDBI    Notes
  #   ---------  --------  --------  -------------------------------------
  #   TIMESTAMP      Time  DateTime
  #   TIMESTAMP  DateTime  DateTime  (if out of range of Time)
  #        CHAR     'a   '      'a'
  #
  RTRIM_RE   = ::Regexp.new(/ +\z/)
  TIME_ZONE  = ::DateTime.now.zone # TODO - allow changing TZ
  STR_RTRIM  = proc { |str| str.sub(RTRIM_RE, '') }
  IS_STR     = proc { |x| x.kind_of?(::String) }
  IS_TIME    = proc { |x| x.kind_of?(::Time) }
  TIME_TO_DT = proc { |t|
                 ::DateTime.new(t.year,
                                t.month,
                                t.day,
                                t.hour,
                                t.min,
                                t.sec + Rational(t.usec, 10**6),
                                Rational(t.utc_offset, 60 * 60 * 24))
               }

  OUTPUT_MAP = RDBI::Type.create_type_hash(RDBI::Type::Out).merge({
                 :timestamp => [TypeLib::Filter.new(IS_TIME, TIME_TO_DT)],
                 :char      => [TypeLib::Filter.new(IS_STR, STR_RTRIM)]
               })

  def initialize(query, dbh)
    super(query, dbh)

    @fb_stmt = Rubyfb::Statement.new(dbh.fb_cxn,
                                     dbh.fb_txns[-1],
                                     query,
                                     dbh.fb_dialect)

    @index_map = Epoxy.new(query).indexed_binds
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

end #-- class Statement
end #-- class RDBI::Driver::Rubyfb
