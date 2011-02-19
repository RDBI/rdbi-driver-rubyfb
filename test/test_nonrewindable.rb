require 'helper'

class TestNonRewindable < Test::Unit::TestCase
  attr_accessor :dbh

  def setup
    self.dbh = init_database
    dbh.rewindable_result = false
  end

  def teardown
    @dbh.disconnect if @dbh && @dbh.connected?
  end

  def assert_nret(message = nil)
    e = nil
    assert_block(message) do
      begin
        yield
      rescue Exception => e
        break
      end
      false
    end
    assert_raise(RDBI::Cursor::NotRewindableError, message, &block)
  end
  def assert_nre(message = nil)
    assert_raise(RDBI::Cursor::NotRewindableError, message) do
      yield
    end
  end

  def test_rewindability_inherited
    assert(!dbh.rewindable_result)
    dbh.transaction do
      dbh.prepare('SELECT CURRENT_TIMESTAMP FROM RDB$DATABASE') do |sth|
        assert(!sth.rewindable_result)
        sth.execute do |res|
          assert(!res.rewindable_result)
        end
      end
    end
  end

  def test_n
    dbh.transaction do
      dbh.execute('select I, VC from RUBYFB_TEST ORDER BY I') do |res|
        TEST_ROWS.each_with_index do |r, i|
          assert_equal([r], res.fetch(1),
                       "#fetch(1) of row at index #{i} failed")
        end

        assert_nre { res.rewind }

        assert_nothing_raised do res.fetch(2) end
        assert_equal([], res.fetch(2),
                     "#fetch(2) at end-of-records was not empty set")
      end
    end

  end

  def test_first_last
    first, last = [TEST_ROWS.first, TEST_ROWS.last]

    dbh.transaction do
      dbh.execute('select I, VC from RUBYFB_TEST ORDER BY I') do |res|
        assert_equal(first, res.fetch(:first))
        assert_equal(last, res.fetch(:last))

        assert_equal([], res.fetch(2),
                     "#fetch(2) at end-of-records was not empty set")

        assert_nre { res.fetch(:first) }
        assert_nre { res.fetch(:last)  }
      end
    end
  end

  def test_all
    sql = %q(select I, VC from RUBYFB_TEST where VC LIKE 'f%' ORDER BY I)
    expected = [[1, 'first'], [4, 'fourth'], [5, 'fifth']]

    dbh.transaction do
      dbh.execute(sql) do |res|
        assert_equal(expected, res.fetch(:all))
        assert_equal([], res.fetch(2),
                   "#fetch(2) at end-of-records was not empty set")
        assert_nre("Repeated :all did not raise error") { res.fetch(:all) }
      end
      dbh.execute(sql) do |res|
        assert_nothing_raised { res.fetch(1) }
        assert_nre(":all after fetch did not raise error") { res.fetch(:all) }
      end
    end
  end

  def test_rest
    dbh.transaction do
      dbh.execute('select I, VC from RUBYFB_TEST ORDER BY I') do |res|
        assert_nothing_raised { 2.times do res.fetch end }
        assert_equal(TEST_ROWS[2..-1], res.fetch(:rest))

        assert_equal([], res.fetch(2),
                     "#fetch(2) at end-of-records was not empty set")

        assert_equal([], res.fetch(:rest),
                     "Repeated :rest did not return empty set")
        assert_nre { res.rewind }
      end
    end
  end

  def test_result_count
    dbh.execute('select * from RUBYFB_TEST') do |res|
      assert_equal(0, res.result_count, "Multi-row #result_count pre-fetch was incorrect")
      (1..5).each do |i|
        assert_nothing_raised { res.fetch }
        assert_equal(i, res.result_count, "Multi-row #result_count after fetch no. #{i} incorrect")
      end
    end

    dbh.execute('select * from RUBYFB_TEST where 1=0') do |res|
      assert_equal(0, res.result_count, "Zero-row select #result_count pre-fetch was incorrect")
      assert_nothing_raised { res.fetch }
      assert_equal(0, res.result_count, "Zero-row select #result_count post-fetch was incorrect")
    end

    dbh.execute('select count(1) from RUBYFB_TEST') do |res|
      assert_equal(0, res.result_count, "One-row select #result_count pre-fetch was incorrect")
      assert_nothing_raised { res.fetch }
      assert_equal(1, res.result_count, "SELECT count(1) #result_count was incorrect")
    end
  end

  def test_affected_count
    dbh.execute(%q|delete from RUBYFB_TEST where VC like 'f%'|) do |res|
      assert_equal(3, res.affected_count)
    end
  end
end
