require 'helper'

class TestDatabase < Test::Unit::TestCase
  attr_accessor :dbh

  def teardown
    @dbh.disconnect if @dbh && @dbh.connected?
  end

  def test_connect
    self.dbh = new_database
    assert dbh
    assert_kind_of( RDBI::Driver::Rubyfb::Database, dbh )
    assert_kind_of( RDBI::Database, dbh )
    assert_equal( dbh.database_name, role[:database] )
    dbh.disconnect
    assert ! dbh.connected?
  end

  def test_disconnect_unfinished_result
    self.dbh = new_database
    result = dbh.execute('SELECT 1 FROM RDB$DATABASE UNION ALL SELECT 2 FROM RDB$DATABASE')
    result.fetch
    dbh.disconnect
  end

  def test_ping
    self.dbh = new_database
    my_role = role.dup
    driver = my_role.delete(:driver)

    assert_kind_of(Numeric, dbh.ping)
    assert_kind_of(Numeric, RDBI.ping(driver, my_role))

    # Error on disconnected DB
    dbh.disconnect
    assert_raises(RDBI::DisconnectedError) do
      dbh.ping
    end

    # XXX This should still work because it connects. Obviously, testing a
    # downed database is gonna be pretty hard.
    assert_kind_of(Numeric, RDBI.ping(driver, my_role))
  end

  def test_transaction
    self.dbh = new_database
    assert dbh

    assert(! dbh.in_transaction?)

    # Commit ends transaction
    dbh.transaction do
      assert(dbh.in_transaction?)
      dbh.commit
      assert(! dbh.in_transaction?, "#commit ends transaction")
    end

    # Rollback ends transaction
    assert(! dbh.in_transaction?)
    dbh.transaction do
      assert(dbh.in_transaction?)
      dbh.rollback
      assert(! dbh.in_transaction?, "#rollback ends transaction")
    end
  end

  def test_execute
    self.dbh = new_database

    assert_nothing_raised('Parameter-less bind throws no exceptions') do
      dbh.execute('SELECT 1 FROM RDB$DATABASE WHERE 1=0').finish
    end

    assert_nothing_raised('Parameter bind throws no exceptions') do
      dbh.execute('SELECT 1 FROM RDB$DATABASE WHERE 1=?', 0).finish
    end
  end

  def test_rest
    # XXX move me to result test
    self.dbh = init_database
    remainder = nil
    dbh.transaction do
      dbh.execute('select I, VC from RUBYFB_TEST') do |res|
        assert_nothing_raised { res.fetch }
        assert_nothing_raised { res.fetch }
        remainder = res.fetch(:rest)
        assert_equal([], res.fetch)
        assert_equal([], res.fetch(5))
      end
    end
    assert_equal([[3, 'third'], [4, 'fourth'], [5, 'fifth']], remainder)
  end
end
