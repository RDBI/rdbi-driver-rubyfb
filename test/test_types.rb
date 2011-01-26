require 'helper'

require 'date'

class TestTypes < Test::Unit::TestCase
  attr_accessor :dbh

  def self.simple_type_test(name, literal, expected)
    name = ('test_' + name.to_s) unless name.to_s =~ /^test_./

    define_method(name.to_sym) do
      fetched = select_one_literal(self.dbh, literal)
      assert_kind_of(expected.class, fetched, "SELECT #{literal} (class)")
      assert_equal(expected, fetched, "SELECT #{literal} (value)")
    end
  end

  # explicit_cast_test :some_sql_type, literal, expected
  #
  #  assert "CAST(#{literal} AS SOME SQL TYPE)" => expected
  #
  def self.explicit_cast_test(name, literal, expected)
    sql_type = name.to_s.tr('_', ' ').upcase
    literal = "CAST(#{literal} AS #{sql_type})"

    method_name = ('cast_as_' + name.to_s.gsub(/\(\d+(,\d+)?\)/, '')).to_sym
    simple_type_test(method_name, literal, expected)
  end

  # == Explicit type tests ==================================================
  #                    TEST                EXPECTED
  explicit_cast_test :double_precision, '1.001', 1.001

  explicit_cast_test :date, "'2010-01-01'", ::Date.parse("2010-01-01")

  dt_expected = ::DateTime.parse("2010-01-01 01:02:03 #{DateTime.now.zone}")
  explicit_cast_test :timestamp, "'2010-01-01 01:02:03'", dt_expected

  explicit_cast_test :integer,          '128',  128
  explicit_cast_test :smallint,           '1',  1
  explicit_cast_test :bigint,            '-2', -2
  explicit_cast_test :"numeric(8,4)", '-2.07', -2.07
  explicit_cast_test :"decimal(9,3)",  '0.72',  0.72
  explicit_cast_test :"char(3)",      "'foo'",  "foo"
  explicit_cast_test :"varchar(3)",   "'foo'",  "foo"

  # == Implicit type tests ==================================================
  simple_type_test :implicit_integer,  '-100', -100
  simple_type_test :implicit_string,  "'foo'", 'foo'
  simple_type_test :implicit_float,   '1.001', 1.001
  simple_type_test :implicit_float,     '2.0', 2.0

  # == String rtrim tests ("ChopBlanks") ====================================
  simple_type_test :rtrim_blanks_only,       "' foo  \n'", " foo  \n"
  simple_type_test :rtrim_multiline,       "'foo\nbar  '", "foo\nbar"
  simple_type_test :rtrim,                  "'   foo   '", '   foo'
  simple_type_test :rtrim_cast, "CAST('foo' AS CHAR(31))", 'foo'

  def setup
    @dbh = new_database
  end

  def teardown
    @dbh.disconnect if @dbh && @dbh.connected?
  end

end
