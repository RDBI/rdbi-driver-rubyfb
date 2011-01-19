require 'rdbi'
require 'rubyfb'

class RDBI::Driver::Rubyfb::Cursor < RDBI::Cursor
  # FIXME - SPEC - RDBI::Result initialized with a fixed SIZE attribute but
  #         not all drivers will know size/result_count in advance.  SHould be
  #         dynamically computed
  #
  # FIXME - we need to read ahead one row, b/c exhausted? is only set after
  #         attempting to fetch beyond the result set...
  attr_reader :affected_count

  def initialize(handle)
    super(handle)
    @index = 0 # FIXME - move to superclass

    # XXX - what is spec here?  Zero or nil for not-applicable counts?
    @affected_count = handle.kind_of?(Numeric) ? handle : 0
    #puts "#{self.class.name} rows #{result_count}, affected #{affected_count}"
  end

  def each
    while row = next_row
      yield row
    end
  end

  def [](i)
    if i < @index
      raise RDBI::Cursor::NotRewindableError.new('requested index requires rewindable cursor')
    end
    (0...(i-1)).each do next_row end
    next_row
  end

  # def affected_count ... end  (attr_reader)

  def all
    if @index > 0
      raise RDBI::Cursor::NotRewindableError.new('#all() requested on non-rewindable cursor after cursor advance')
    end
    rest
  end

  def empty?
    # XXX - API - move to common implementation
    #       Is this reliable on DML statements?
    result_count == 0 and last_row?
  end

  def fetch(count = 1)
    # FIXME - move common implementation to RDBI::Cursor
    return [] if last_row?
    (0...count).collect { next_row }
  end

  def finish
    @handle.close
  end

  def first
    return next_row if @index == 0
    # FIXME - provide mixin which tracks rewindability, throws errors
    raise RDBI::Cursor::NotRewindableError.new('#first() called after a fetch on a non-rewindable cursor')
  end

  def last
    ret = nil
    while row = next_row
      ret = row
    end
    ret
  end

  def last_row?
    @handle.exhausted?
  end

  def next_row
    row = @handle.fetch.values rescue nil
    if row
      @index += 1
    end
    row
  end

  def rest
    self.collect {|row| row}
  end

  def result_count
    @handle.row_count rescue 0 # FIXME - API - just rows fetched so far!  SPEC clarify
  end

  def rewind
    return if @index == 0 # FIXME - API - Ugh.  What should we do here to
    #       permit result.as(:Foo) on non-rewindables?
    raise RDBI::Cursor::NotRewindableError.new('#rewind() called on non-rewindable cursor')
  end

end # -- Cursor
