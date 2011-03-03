module Keep
  module Relations
    class Selection < Relation
      attr_reader :operand, :predicate

      def initialize(operand, predicate)
        @operand = operand
        @predicate = resolve(predicate.to_predicate)
      end

      delegate :get_table, :to => :operand

      def columns
        operand.columns.map do |column|
          derive(column)
        end
      end

      def visit(query)
        operand.visit(query)
        query.add_condition(predicate.resolve_in_query(query))
      end

      protected

      def operands
        [operand]
      end
    end
  end
end
