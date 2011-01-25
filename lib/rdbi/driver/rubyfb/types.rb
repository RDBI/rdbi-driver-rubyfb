class RDBI::Driver::Rubyfb
  module Types
    TYPES = {
        7 => :SMALLINT,
        8 => :INTEGER,
       16 => :BIGINT,
       10 => :FLOAT,
       27 => :DOUBLE,
       14 => :CHAR,
       37 => :VARCHAR,
       13 => :TIME,
       12 => :DATE,
       35 => :TIMESTAMP,
      261 => :BLOB
    }

    # Input:  rdb$field_type, rdb$field_sub_type codes
    # Output: [Rubyfb_type_symbol, RDBI_type_symbol]
    def self.field_type_to_rubyfb(type, subtype)
      t = TYPES.fetch(type, :UNKNOWN).downcase
      if [:bigint, :integer, :smallint].include?(t)
        t = case subtype
            when 2
              :decimal
            when 1
              :numeric
            else
              t
            end
      end
      t
    end

    def self.rubyfb_to_rdbi(type, scale)
      case type
      when :bigint, :integer, :smallint
        scale > 0 ? :float : type
      else
        type
      end
    end
  end
end
