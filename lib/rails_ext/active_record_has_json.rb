module ActiveRecord
  class TypedJson
    def initialize(schema, data:)
      @schema, @data = schema, data
    end

    def assign_data_with_type_casting(new_data)
      new_data.each { |key, value| self.send("#{key}=", value) }
    end

    private
      def method_missing(method_name, *args, **kwargs)
        key = method_name.to_s.remove(/(\?|=)/)

        if key_type = @schema[key.to_sym]
          if method_name.ends_with?("?")
            @data[key].present?
          elsif method_name.ends_with?("=")
            value = args.first
            @data[key] = ActiveModel::Type.lookup(key_type).cast(value)
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
  end

  class Base
    class << self
      def has_json(delegate: false, **schemas)
        schemas.each do |name, schema|
          define_method(name)       { ActiveRecord::TypedJson.new(schema, data: self[name]) }
          define_method("#{name}=") { |data| send(name).assign_data_with_type_casting(data) }

          schema.keys.each do |schema_key|
            define_method(schema_key)       { send(name).send(schema_key) }
            define_method("#{schema_key}?") { send(name).send("#{schema_key}?") }
            define_method("#{schema_key}=") { |value| send(name).send("#{schema_key}=", value) }
          end if delegate
        end
      end

      def has_settings(schema)
        has_json settings: schema, delegate: true
      end
    end
  end
end
