require 'rdbi'
require 'rubyfb'

class RDBI::Driver::Rubyfb < RDBI::Driver
  def initialize(*args)
    super(Database, *args)
  end
end

require 'rdbi/driver/rubyfb/database'
require 'rdbi/driver/rubyfb/statement'
require 'rdbi/driver/rubyfb/cursor'
require 'rdbi/driver/rubyfb/types'
