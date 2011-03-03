module Keep
  module Expressions
    class Equal
      attr_reader :left, :right
      def initialize(left, right)
        @left, @right = left, right
      end
      
      def resolve_in_relations(relations)
        Equal.new(left.resolve_in_relations(relations), right.resolve_in_relations(relations))
      end

      def resolve_in_query(query)
        Equal.new(left.resolve_in_query(query), right.resolve_in_query(query))
      end

      def to_sql
        "#{left.to_sql} = #{right.to_sql}"
      end
    end
  end
end