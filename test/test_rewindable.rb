require 'helper'

class TestRewindable < Test::Unit::TestCase
  attr_accessor :dbh

  def setup
    self.dbh = init_database
    dbh.rewindable_result = true
  end

  def teardown
    @dbh.disconnect if @dbh && @dbh.connected?
  end

  def test_rewindability_inherited
    assert(dbh.rewindable_result)
    dbh.transaction do
      dbh.prepare('SELECT CURRENT_TIMESTAMP FROM RDB$DATABASE') do |sth|
        assert(sth.rewindable_result)
        sth.execute do |res|
          assert(res.rewindable_result)
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
        res.rewind
        assert_nothing_raised do res.fetch(2) end
        assert_equal(TEST_ROWS[2,2], res.fetch(2),
                     "#fetch(2) at index 2 failed")
      end
    end

  end

  def test_first_last
    first, last = [TEST_ROWS.first, TEST_ROWS.last]

    dbh.transaction do
      dbh.execute('select I, VC from RUBYFB_TEST ORDER BY I') do |res|
        assert_equal(first, res.fetch(:first))
        assert_equal(last, res.fetch(:last))

        # advance to end-of-records
        assert_equal(TEST_ROWS, res.fetch( TEST_ROWS.size + 10 ),
                     "#fetch(n) beyond end-of-records failed")

        assert_equal(first, res.fetch(:first),
                     ":first at end-of-records failed")
        assert_equal(last, res.fetch(:last),
                     ":last at end-of-records failed")
      end
    end
  end

  def test_all
    sql = %q(select I, VC from RUBYFB_TEST where VC LIKE 'f%' ORDER BY I)
    expected = [[1, 'first'], [4, 'fourth'], [5, 'fifth']]

    dbh.transaction do
      dbh.execute(sql) do |res|
        assert_equal(expected, res.fetch(:all))
        assert_equal(expected, res.fetch(:all),
                     "Repeated :all did not return all rows")
        assert_nothing_raised do res.rewind end
        assert_equal(expected, res.fetch(:all),
                     ":all after #rewind did not return all rows")

        # advance to end-of-records
        assert_equal(expected, res.fetch( expected.size + 100 ),
                     "#fetch(n) beyond end-of-records failed")

        # :all is not affected by index position
        assert_equal(expected, res.fetch(:all),
                     ":all at end-of-records did not return all rows")
      end
    end
  end

  def test_rest
    dbh.transaction do
      dbh.execute('select I, VC from RUBYFB_TEST ORDER BY I') do |res|
        assert_nothing_raised { 2.times do res.fetch end }
        assert_equal(TEST_ROWS[2..-1], res.fetch(:rest))

        assert_equal(TEST_ROWS, res.fetch(:all),
                     ":all after :rest did not return expected rows")

        assert_nothing_raised { res.rewind }
        assert_equal(TEST_ROWS, res.fetch(:rest),
                     ":rest at index 0 was not equal to :all")

        assert_equal(TEST_ROWS, res.fetch( TEST_ROWS.size + 10 ))
        assert_equal([], res.fetch(:rest),
                     ":rest at end-of-records was not empty set")
      end
    end
  end
end
