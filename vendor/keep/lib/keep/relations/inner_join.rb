module Keep
  module Relations
    class InnerJoin < Relation
      attr_reader :left, :right, :predicate

      def initialize(left_operand, right_operand, predicate)
        @left, @right = left_operand.to_relation, right_operand.to_relation
        @predicate = resolve(predicate.to_predicate)
      end

      def get_table(name)
        left.get_table(name) || right.get_table(name)
      end

      def columns
        (left.columns + right.columns).map do |column|
          derive(column)
        end
      end

      def visit(query)
        query.table_ref = table_ref(query)
        query.select_list = columns.map do |derived_column|
          query.resolve_derived_column(derived_column, :qualified)
        end
      end

      def table_ref(query)
        Sql::InnerJoinedTableRef.new(left.table_ref(query), right.singular_table_ref(query), predicate.resolve_in_query(query))
      end

      protected

      def operands
        [left, right]
      end
    end
  end
end
