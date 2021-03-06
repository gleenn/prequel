module Prequel
  class Tuple
    class_attribute :relation

    class << self
      delegate :columns, :to => :relation

      def def_field_reader(name)
        define_method(name) do
          get_field_value(name)
        end
      end

      def new_from_database(attributes)
        new(attributes).tap(&:mark_clean)
      end
    end

    def initialize(attributes={})
      initialize_fields
      soft_update_fields(attributes)
    end

    delegate :columns, :to => :relation

    def soft_update_fields(values, mark_clean=false)
      values.each do |name, value|
        set_field_value(name, value, mark_clean)
      end
    end

    def get_field_value(name)
      fields_by_name[name].try(:value)
    end

    def field_values
      fields_by_name.inject({}) do |h, (name, field)|
        h[name] = field.value
        h
      end
    end

    def clean?
      !dirty?
    end

    def dirty?
      fields.any?(&:dirty?)
    end

    def dirty_field_values
      fields_by_name.inject({}) do |h, (name, field)|
        h[name] = field.value if field.dirty?
        h
      end
    end

    def get_record(name)
      nil
    end

    delegate :inspect, :to => :field_values

    def mark_clean
      fields.each(&:mark_clean)
    end

    protected
    attr_reader :fields_by_name

    def fields
      fields_by_name.values
    end

    def initialize_fields
      @fields_by_name = {}
      columns.each do |column|
        fields_by_name[column.name] = Field.new(self, column)
      end
    end

    def set_field_value(name, value, mark_clean=false)
      field = fields_by_name[name]
      unless field
        raise "No field found #{name.inspect}"
      end
      field.value = value
      field.mark_clean if mark_clean
    end
  end
end

