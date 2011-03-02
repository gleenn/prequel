module Keep
  module Relations
    class Selection < Relation
      attr_reader :operand, :predicate

      def initialize(operand, predicate)
        @operand = operand
        @predicate = predicate.to_predicate.resolve_columns(operand)
      end

      def get_column(name)
        derive_column_from(operand, name)
      end

      def columns
        operand.columns.map do |column|
          derive_column(column)
        end
      end

      def visit(query)
        query.add_condition(predicate)
        operand.visit(query)
      end
    end
  end
end
