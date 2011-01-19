require 'rdbi/driver/rubyfb'
require 'epoxy'
require 'rubyfb'

class RDBI::Driver::Rubyfb::Database < RDBI::Database
  attr_accessor :fb_db
  attr_accessor :fb_cxn
  attr_reader   :fb_dialect
  attr_reader   :fb_txns

  def initialize(*args)
    # XXX is :dbname required?  is :auth an appropriate name?
    # FIXME - create database, what options?
    # FIXME - dialect
    super(*args)
    self.database_name = @connect_args[:isc_database] || @connect_args[:database] || @connect_args[:db]
    self.fb_db = Rubyfb::Database.new(self.database_name)
    @fb_dialect = 3

    user = @connect_args[:user] || @connect_args[:username] || ENV['ISC_USER']
    pass = @connect_args[:password] || @connect_args[:auth] || ENV['ISC_PASSWORD']
    @fb_cxn = @fb_db.connect(user, pass)
    @fb_txns = []
  rescue Rubyfb::FireRubyException => e
    raise RDBI::Error.new(e.message)
  end

  def disconnect
    # XXX - fails with outstanding txn
    @fb_cxn.close unless @fb_cxn.closed?
    super
  end

  def transaction(&block)
    @fb_txns << Rubyfb::Transaction.new(@fb_cxn)
    super &block
  end

  def commit
    # FIXME - in_trans? check
    @fb_txns.pop.commit
    super
  end

  def rollback
    # FIXME - in_trans? check
    @fb_txns.pop.rollback
    super
  end

  def new_statement(query)
    RDBI::Driver::Rubyfb::Statement.new(query, self)
  end

  # Return the elapsed time taken to check the database connection, or
  # an RDBI::DisconnectedError if not connected
  def ping
    # perl-DBD-InterBase calls isc_database_info(), but rubyfb-0.5.5 does
    # not expose that interface
    t0 = ::Time.now
    @fb_cxn.execute_immediate('SELECT 1 AS PING FROM RDB$DATABASE') do |r|
    end
    t1 = ::Time.now
    t0.to_i - t1.to_i
  rescue Rubyfb::FireRubyException => e
    raise RDBI::DisconnectedError.new(e.message)
  end

  # def table_schema
  # def schema
end # -- class Database
