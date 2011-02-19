require 'rdbi'
require 'rubyfb'

##
#
# RDBI database driver for the robust and SQL-compliant Firebird RDBMS, an
# open-source member of the InterBase genus.  See the documentation for
# RDBI::Driver::Rubyfb::Database for more information.
#
class RDBI::Driver::Rubyfb < RDBI::Driver
  def initialize(*args)
    super(Database, *args)
  end
end

require 'rdbi/driver/rubyfb/database'
require 'rdbi/driver/rubyfb/statement'
require 'rdbi/driver/rubyfb/cursor'
require 'rdbi/driver/rubyfb/types'
