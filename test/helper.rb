require 'rubygems'
require 'test/unit'
require 'rubyfb'     # XXX gem ... version?
require 'rdbi-dbrc'

require 'rdbi/driver/rubyfb'

class Test::Unit::TestCase
  DBRC_SECTION = :rubyfb_test         # Change as needed

  SQL_PRE = ['DROP TABLE RUBYFB_TEST']
  SQL = [
    'CREATE TABLE RUBYFB_TEST (I INT PRIMARY KEY, VC VARCHAR(32))',
    "INSERT INTO RUBYFB_TEST (I, VC) VALUES (1, 'first')",
    "INSERT INTO RUBYFB_TEST (I, VC) VALUES (2, 'second')",
    "INSERT INTO RUBYFB_TEST (I, VC) VALUES (3, 'third')",
    "INSERT INTO RUBYFB_TEST (I, VC) VALUES (4, 'fourth')",
    "INSERT INTO RUBYFB_TEST (I, VC) VALUES (5, 'fifth')",
  ]

  def new_database
    RDBI::DBRC.connect(DBRC_SECTION)
  end

  def init_database
    dbh = new_database
    dbh.transaction do |dbh|
      dbh.execute('DROP TABLE RUBYFB_TEST') rescue nil
      dbh.execute('CREATE TABLE RUBYFB_TEST (I INT PRIMARY KEY, VC VARCHAR(32))');
    end
    dbh.transaction do |dbh|
      dbh.prepare('INSERT INTO RUBYFB_TEST (I, VC) VALUES (?, ?)') do |stmt|
        %w(first second third fourth fifth).each_with_index do |vc, i|
          stmt.execute(i+1, vc)
        end
      end
    end
    dbh
  end

  def role
    RDBI::DBRC.roles[DBRC_SECTION]
  end

  def assert_hard_equivalence(expected, actual, message = nil)
    assert_kind_of(expected.class, actual, message)
    assert_equal(expected, actual, message)
  end

  def select_one_literal(dbh, literal)
    ret = nil
    dbh.transaction do
      dbh.execute("SELECT #{literal} FROM RDB$DATABASE") do |result|
        ret = result.fetch[0][0]
      end
    end
    ret
  end
end # -- Test::Unit::TestCase
