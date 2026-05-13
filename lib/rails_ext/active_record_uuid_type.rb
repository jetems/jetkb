# Custom UUID attribute type for MySQL binary storage with base36 string representation
module ActiveRecord
  module Type
    class Uuid < Binary
      BASE36_LENGTH = 25 # 36^25 > 2^128

      class << self
        def generate
          uuid = SecureRandom.uuid_v7
          hex = uuid.delete("-")
          hex_to_base36(hex)
        end

        def hex_to_base36(hex)
          hex.to_i(16).to_s(36).rjust(BASE36_LENGTH, "0")
        end

        def base36_to_hex(base36)
          base36.to_s.to_i(36).to_s(16).rjust(32, "0")
        end
      end

      def serialize(value)
        return unless value

        binary = Uuid.base36_to_hex(value).scan(/../).map(&:hex).pack("C*")
        super(binary)
      end

      def deserialize(value)
        return unless value

        hex = value.to_s.unpack1("H*")
        Uuid.hex_to_base36(hex)
      end

      def cast(value)
        value
      end
    end
  end
end

# Register the UUID type for Trilogy (MySQL) and SQLite3 adapters
ActiveRecord::Type.register(:uuid, ActiveRecord::Type::Uuid, adapter: :trilogy)
ActiveRecord::Type.register(:uuid, ActiveRecord::Type::Uuid, adapter: :sqlite3)

# PostgreSQL stores UUIDs natively (16 bytes via the `uuid` type), but
# userland code still expects the 25-char base36 facade. PostgresqlUuid
# serializes to/from the canonical 36-char hyphenated UUID form that PG
# accepts, keeping the base36 representation on the Ruby side.
module ActiveRecord
  module Type
    class PostgresqlUuid < Uuid
      def serialize(value)
        return unless value

        hex = Uuid.base36_to_hex(value)
        "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
      end

      def deserialize(value)
        return unless value

        hex = value.to_s.delete("-")
        Uuid.hex_to_base36(hex)
      end
    end
  end
end

ActiveRecord::Type.register(:uuid, ActiveRecord::Type::PostgresqlUuid, adapter: :postgresql)
