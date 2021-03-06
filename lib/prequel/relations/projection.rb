module Prequel
  module Relations
    class Projection < Relation
      attr_reader :operand

      def initialize(operand, *expressions)
        @operand = operand
        assign_derived_columns(expressions)
      end

      def get_column(name)
        if name.to_s.include?("__")
          super
        else
          derived_columns_by_name[name]
        end
      end

      def columns
        derived_columns.values
      end

      def visit(query)
        operand.visit(query)
        query.select_list = columns.map do |derived_column|
          query.resolve_derived_column(derived_column)
        end

        if projected_table
          projected_table_ref = query.singular_table_refs[projected_table]
          query.projected_table_ref = projected_table_ref
          query.tuple_builder = projected_table_ref
        else
          query.tuple_builder = self
        end
      end

      def build_tuple(field_values)
        tuple_class.new_from_database(field_values)
      end

      def tuple_class
        @tuple_class ||= Class.new(Tuple).tap do |tuple_class|
          tuple_class.relation = self
          columns.each do |column|
            tuple_class.def_field_reader(column.name)
          end
        end
      end

      def infer_join_columns(columns)
        if projected_table
          projected_table.infer_join_columns(columns)
        else
          raise "Cannot infer join columns through a projection"
        end
      end

      def get_table(name)
        projected_table if projected_table.name == name
      end

      derive_equality :operand, :projected_table, :projected_columns

      def wire_representation
        raise "Can only wire-represent table projections" unless projected_table
        {
          :type => 'table_projection',
          :operand => operand.wire_representation,
          :projected_table => projected_table.name.to_s
        }
      end

      protected
      attr_reader :projected_table, :projected_columns

      def assign_derived_columns(expressions)
        if @projected_table = detect_projected_table(expressions)
          projected_table.columns.map do |column|
            derive(resolve(column.qualified_name.as(column.name)))
          end
        else
          @projected_columns = expressions.map do |column_name|
            derive(resolve(column_name))
          end
        end
      end

      def detect_projected_table(args)
        return false unless args.size == 1
        arg = args.first
        if arg.instance_of?(Table)
          table_name = arg.name
        elsif arg.instance_of?(Class) && arg.respond_to?(:table)
          table_name = arg.table.name
        elsif arg.instance_of?(Symbol)
          return false if arg =~ /__/
          table_name = arg
        else
          return false
        end

        operand.get_table(table_name)
      end

      def operands
        [operand]
      end
    end
  end
end
