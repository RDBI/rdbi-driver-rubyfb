require 'rdbi'
require 'rubyfb'

class RDBI::Driver::Rubyfb

  # :nodoc:
  module CursorAffectedCountImpl
    def affected_count
      @affected_count ||= (handle.kind_of?(Numeric) ? handle : 0)
    end
  end # -- CursorAffectedCountImpl

  ##
  # Simple rewindable cursor, reading all results into memory.
  #
  # Not instantiated nor accessed directly.  Call Database#execute() or
  # Statement#execute() with 'rewindable_result = true'
  class ArrayCursor < RDBI::Cursor
    include CursorAffectedCountImpl

    def initialize(rfb_handle)
      super(rfb_handle)
      @index = 0
      @rows  = if rfb_handle.kind_of?(::Rubyfb::ResultSet)
                 rfb_handle.collect { |row| row.values }
               else
                 []
               end
    end

    def [](i)
      @rows[i]
    end

    def all
      @rows
    end

    def empty?
      @rows.size == 0
    end

    def finish; end

    def first
      @rows.first
    end

    def last
      @rows.last
    end

    def last_row?
      @index == @rows.size
    end

    def result_count
      @rows.size
    end

    ### @index-based row access ###
    def fetch(count = 1)
      if r = @rows[@index, count]
        @index += [count, r.size].min
      end
      r
    end

    def next_row
      return if last_row?
      val = @rows[@index]
      @index += 1
      val
    end

    def rewind
      @index = 0
    end

    def rest
      @rows[@index..-1]
    end
  end # -- class ArrayCursor

  ##
  # Non-rewindable cursor class, which does not load all rows into memory.
  #
  # Not instantiated nor accessed directly.  Call Database#execute() or
  # Statement#execute() with 'rewindable_result = false'
  class ForwardOnlyCursor < RDBI::Cursor
    include CursorAffectedCountImpl
    # :nodoc:
    # RDBI::Cursor#each relies on last_row?(), but Rubyfb::Cursor does
    # not know its result set size in advance, and does not know that it
    # is #exhausted? until we attempt to move past the end.  So...
    def each
      while row = next_row
        yield row
      end
    end

    def [](i)
      if i < result_count
        raise RDBI::Cursor::NotRewindableError.new('requested index requires rewindable cursor')
      end
      (0...(i-1)).each do next_row end
      next_row
    end

    def all
      return @handle.collect {|r| r.values} if 0 == @handle.row_count
      raise RDBI::Cursor::NotRewindableError.new(':all requested on non-rewindable cursor after advance')
    end

    def rest
      self.collect { |r| r }
    end

    def empty?
      0 == result_count and last_row?
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
      return next_row if 0 == result_count
      # FIXME - provide mixin which tracks rewindability, throws errors
      raise RDBI::Cursor::NotRewindableError.new(':first requested after advancing non-rewindable cursor')
    end

    def last
      ret = nil
      while row = next_row
        ret = row
      end
      return ret if ret
      raise RDBI::Cursor::NotRewindableError.new(':last requested after advancing past end of non-rewindable cursor')
    end

    def last_row?
      @handle.exhausted? rescue true
    end

    def next_row
      @handle.fetch.values rescue nil
    end

    def result_count
      @handle.row_count rescue 0
    end

    def rewind
      # Yuck - special case ignore rewind at index 0, since
      # ResultSet#as(:Blah) infelicitously forces a #rewind()
      return if 0 == result_count
      raise RDBI::Cursor::NotRewindableError.new('#rewind() requested on non-rewindable cursor')
    end
  end # -- Cursor
end # -- class RDBI::Driver::Rubyfb
