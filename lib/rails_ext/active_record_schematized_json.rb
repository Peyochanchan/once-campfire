module ActiveRecord
  class SchematizedJson
    def initialize(schema, data:)
      @schema, @data = schema, data
      update_data_with_schema_defaults
    end

    def assign_data_with_type_casting(new_data)
      new_data.each { |k, v| public_send "#{k}=", v }
    end

    private
      def method_missing(method_name, *args, **kwargs)
        key = method_name.to_s.remove(/(\?|=)/)

        if @schema.key? key.to_sym
          if method_name.ends_with?("?")
            @data[key].present?
          elsif method_name.ends_with?("=")
            value = args.first
            @data[key] = lookup_schema_type_for(key).cast(value)
          else
            @data[key]
          end
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @schema.key?(method_name.to_s.remove(/[?=]/).to_sym) || super
      end

      def lookup_schema_type_for(key)
        type_or_default_value = @schema[key.to_sym]

        case type_or_default_value
        when :boolean, :integer, :string
          ActiveModel::Type.lookup(type_or_default_value)
        when TrueClass, FalseClass
          ActiveModel::Type.lookup(:boolean)
        when Integer
          ActiveModel::Type.lookup(:integer)
        when String
          ActiveModel::Type.lookup(:string)
        else
          raise "Only boolean, integer, or strings are allowed as JSON schema types"
        end
      end

      def update_data_with_schema_defaults
        @data.reverse_merge!(@schema.to_h { |k, v| [ k.to_s, v.is_a?(Symbol) ? nil : v ] })
      end
  end

  class Base
    class << self
      def has_json(delegate: false, **schemas)
        schemas.each do |name, schema|
          define_method(name)       { ActiveRecord::SchematizedJson.new(schema, data: self[name]) }
          define_method("#{name}=") { |data| public_send(name).assign_data_with_type_casting(data) }

          schema.keys.each do |schema_key|
            define_method(schema_key)       { public_send(name).public_send(schema_key) }
            define_method("#{schema_key}?") { public_send(name).public_send("#{schema_key}?") }
            define_method("#{schema_key}=") { |value| send(name).public_send("#{schema_key}=", value) }
          end if delegate

          # Ensures default values are set before saving
          before_save -> { send(name) }
        end
      end

      def has_settings(schema)
        has_json settings: schema, delegate: true
      end
    end
  end
end
