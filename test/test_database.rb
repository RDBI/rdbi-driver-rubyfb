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

  def test_manual_commit
    self.dbh = new_database

    dbh.transaction do dbh.execute('drop table RUBYFB_TEST') rescue nil end
    dbh.execute_modification('create table RUBYFB_TEST (I integer)')
    assert_raise(Rubyfb::FireRubyException) do
      # No such table (FB transactional DDL requires commit before DML)
      dbh.execute_modification('insert into RUBYFB_TEST (I) values (?)', 1)
    end

    dbh.commit

    assert_nothing_raised do
      dbh.execute_modification('insert into RUBYFB_TEST (I) values (?)', 1)
      dbh.commit
    end

    assert_nothing_raised do
      dbh.execute_modification('drop table RUBYFB_TEST')
      dbh.commit
    end
  end

  def test_failed_commit
    self.dbh = new_database

    dbh.transaction do dbh.execute('drop table RUBYFB_TEST') rescue nil end
    dbh.execute_modification('create table RUBYFB_TEST (I integer)')
    dbh.commit

    sth = dbh.prepare('insert into RUBYFB_TEST (I) values (?)')
    sth.execute(1)

    dbh.execute_modification('drop table RUBYFB_TEST')
    assert_raises(Rubyfb::FireRubyException) do
      # 'Object is in use' !
      dbh.commit
    end
    sth.finish

    assert_nothing_raised do
      dbh.commit
    end
  end

  def test_execute
    self.dbh = new_database

    assert_nothing_raised('Parameter-less bind raised an exception') do
      dbh.execute('SELECT 1 FROM RDB$DATABASE WHERE 1=0').finish
    end

    assert_nothing_raised('Parameter bind raised an exception') do
      dbh.execute('SELECT 1 FROM RDB$DATABASE WHERE 1=?', 0).finish
    end
  end

  def test_zero_results
    sth = dbh.prepare('insert into RUBYFB_TEST (I, VC) values (?, ?)')
    res = sth.execute(6, 'sesa')
    assert_equal(1, res.affected_count)
    sth.finish
    assert_equal(1, res.affected_count)
  end
end
