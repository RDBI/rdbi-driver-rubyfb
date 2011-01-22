require 'rdbi'
require 'rubyfb'

class RDBI::Driver::Rubyfb::Cursor < RDBI::Cursor
  # Base class assumes "size" of result set known in advance of fetching

  attr_reader :affected_count

  def initialize(handle)
    super(handle)
    @index = 0 # FIXME - move to superclass

    # XXX - what is spec here?  Zero or nil for not-applicable counts?
    @affected_count = handle.kind_of?(Numeric) ? handle : 0
  end

  # Base class relies on last_row?(), but we don't know result set
  # size in advance and so don't set last_row?() until we attempt to
  # move past the end...
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
    ret = []
    (0...count).each do
      break unless row = next_row
      ret << row
    end
    ret
  end

  def finish
    @handle.close rescue nil
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
    begin
      row = @handle.fetch.values
      @index += 1
    rescue NoMethodError
      # Either @handle wasn't a Rubyfb::ResultSet (as from a DML query), or
      # fetch() was exhausted?() and returned nil.
      class << self; def next_row; nil end end
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
