require 'helper'

class TestQuery < Test::Unit::TestCase
  attr_accessor :dbh

  def setup
    self.dbh = new_database
  end

  def teardown
    @dbh.disconnect if @dbh && @dbh.connected?
  end

  def test_bind_projection_term
    assert_raise(Rubyfb::FireRubyException, "SELECT ? did not raise expected error") do
      dbh.execute('select ? from rdb$database', 1)
    end
  end

  def test_bind_identifier
    assert_raise(Rubyfb::FireRubyException, "SELECT ? did not raise expected error") do
      dbh.execute('select 1 from ?', "rdb$database")
    end
  end

  def test_positional_bind
    sql = <<-__eosql
          select A, B
            from (select 'spam', 'eggs'
                    from rdb$database
                  union all
                  select 'foo', 'bar'
                    from rdb$database) T(A, B)
           where A LIKE ?
                 and
                 1 = ?
          __eosql
    dbh.prepare(sql) do |sth|
      sth.execute('f%', 1) do |res|
        assert_equal([['foo', 'bar']], res.fetch(:all))
      end
      sth.execute('f%', 0) do |res|
        assert_equal([], res.fetch(:all))
      end
    end
  end

  def test_named_bind
    sql = <<-__eosql
          select A, B
            from (select 'spam', 'eggs'
                    from rdb$database
                  union all
                  select 'foo', 'bar'
                    from rdb$database) T(A, B)
           where A LIKE ?pattern
                 and
                 1 = ?intval
          __eosql

    dbh.prepare(sql) do |sth|
      sth.execute({:pattern => 'f%', :intval => 1}) do |res|
        assert_equal([['foo', 'bar']], res.fetch(:all))
      end
      sth.execute({:pattern => 'f%', :intval => 0}) do |res|
        assert_equal([], res.fetch(:all))
      end
    end
  end

end
