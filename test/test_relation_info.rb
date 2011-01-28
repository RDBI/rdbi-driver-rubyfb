require 'helper'

class TestRelationInfo < Test::Unit::TestCase
  attr_accessor :dbh

  COLUMNS = [
    { :PK1 => { :type        => :integer,
                :nullable    => false,
                :primary_key => true, } },
    { :PK2 => { :type        => :numeric,
                :nullable    => false,
                :primary_key => true,
                :precision   => 5,
                :scale       => -2,  } },
    { :TS  => { :type        => :timestamp,
                :nullable    => false,
                :primary_key => false, } },
    { :VC  => { :type        => :varchar,
                :nullable    => true,
                :primary_key => false, } },
  ]

  def setup
    @dbh = new_database
    @dbh.transaction do
      dbh.execute('DROP TABLE rubyfb_test') rescue nil
      dbh.execute <<-eosql
        CREATE TABLE rubyfb_test (
          PK1 INTEGER NOT NULL,
          PK2 NUMERIC(5,2) NOT NULL,
           TS TIMESTAMP NOT NULL,
           VC VARCHAR(16),
          PRIMARY KEY(PK1, PK2)
        )
      eosql
    end
  end

  def teardown
    if dbh and dbh.connected?
      dbh.transaction do
        dbh.execute('DROP TABLE rubyfb_test') rescue nil
      end
      dbh.disconnect
    end
  end

  def test_table_schema_missing
    assert_nil(dbh.table_schema('NoSuchTableHere'))
  end

  def test_schema
    relations = dbh.schema

    assert(relations.length > 0, "At least one relation found")

    relations.each { |r|
      assert_kind_of(RDBI::Schema, r)
      assert(r.tables.length == 1, "One table/view per RDBI::Schema")

      r.columns.each do |c|
        assert_kind_of(RDBI::Column, c)
        assert(r.tables = [c.table], "Column relation name matches RDBI::Schema relation name")
      end
    }
    system_relations = relations.select do |r|
                         # XXX - does not precisely map to rdb$system_flag
                         r.tables[0].to_s =~ /^(MON|RDB)\$/
                       end
    assert(system_relations.length == 0, "No system tables/views in #schema() output")
  end

  def test_table_schema
    info = dbh.table_schema(:rubyfb_test)
    assert(info)
    assert_kind_of(RDBI::Schema, info)

    assert_equal([:rubyfb_test], info.tables, "RDBI::Schema#tables")

    info.columns.each_with_index do |col, i|
      assert_kind_of(RDBI::Column, col)
      expectations = COLUMNS[i][col[:name]]
      assert(expectations, "column #{col[:name]} was expected")

      expectations.each do |attribute, expected|
        assert_equal(expected, col[attribute], "#Column {col[:name]}[#{attribute}]")
      end
    end
  end
end
