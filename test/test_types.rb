require 'helper'

require 'date'

class TestTypes < Test::Unit::TestCase
  attr_accessor :dbh

  # TODO:
  #   - BLOB test (different API)
  #   - implicit types test (because some floating precision is stored as
  #                          BIGINT -- make sure we're getting this right)
  #
  #    fb_type        => [ literal, expected ]
  # -----------------    ------------------------------------------------
  #    "CAST(#{LITERAL} AS FB TYPE)"
  {
    :double_precision => [ '1.001', 1.001 ],
    :date             => [ "'2010-01-01'", ::Date.parse('2010-01-01') ],
    :timestamp        => [ "'2010-01-01 01:02:03'", ::DateTime.parse('2010-01-01 01:02:03') ],
    :integer          => [ '128', 128 ],
    :smallint         => [ '1', 1 ],
    :bigint           => [ '-2', -2 ],
    :"numeric(9,3)"   => [ '-2.07', -2.07 ],
    :"decimal(9,3)"   => [ '0.72', 0.72 ],
    :"char(3)"        => [ "'foo'", 'foo' ],
    :"varchar(3)"     => [ "'foo'", 'foo' ],
  }.each do |fb_type, t|

    method_name = ('test_explicit_' + fb_type.to_s.gsub(/\(\d+(,\d+)?\)/, '')).to_sym
    literal, expected = t
    sql_type = fb_type.to_s.gsub(/_/, ' ').upcase

    define_method method_name do
      cast  = "CAST(#{literal} AS #{sql_type})"
      value = select_one_literal(cast)
      assert_hard_equivalence(expected, value, cast)
    end
  end

  def test_explicit_float
    cast = 'CAST(1.23 AS FLOAT)'
    val  = select_one_literal(cast)
    assert_kind_of(::Float, val, cast)
    assert( (val - 1.23).abs < 0.05, "#{cast} was not even close to 1.23")
  end

  def setup
    @dbh = new_database
  end

  def teardown
    @dbh.disconnect if @dbh && @dbh.connected?
  end

  private

  def assert_hard_equivalence(expected, actual, message = nil)
    assert_kind_of(expected.class, actual, message)
    assert_equal(expected, actual, message)
  end

  def select_one_literal(literal)
    ret = nil
    dbh.transaction do
      dbh.execute("SELECT #{literal} FROM RDB$DATABASE") do |result|
        ret = result.fetch[0][0]
      end
    end
    ret
  end
end
