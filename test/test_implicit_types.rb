require 'helper'

class TestImplicitTypes < Test::Unit::TestCase
  attr_accessor :dbh

  {
    :integer => ['-100', -100],
    :string  => ["'foo'", 'foo'],
    :float   => ['1.001', 1.001], # FB 2.1.3: sqltype BIGINT, sqlscale != 0
  }.each do |expected_ruby_type, t|

    method_name = ('test_implicit_' + expected_ruby_type.to_s).to_sym
    literal, expected = t

    define_method method_name do
      value = select_one_literal(dbh, literal)
      assert_hard_equivalence(expected, value, "SELECT #{literal}")
    end
  end

  def setup
    @dbh = new_database
  end

  def teardown
    @dbh.disconnect if @dbh && @dbh.connected?
  end
end
