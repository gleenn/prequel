module Keep
  module Sql
    class Query
      attr_reader :select_list, :table_ref, :conditions, :literals, :subqueries

      def initialize(relation)
        @relation = relation
        @conditions = []
        @literals = {}
        @subqueries = {}
        relation.visit(self)
      end

      def table_ref=(table_ref)
        raise "A table ref has already been assigned" if @table_ref
        @table_ref = table_ref
        @select_list = table_ref.select_list unless select_list
      end

      def add_condition(predicate)
        conditions.push(predicate)
      end

      def add_literal(literal)
        "v#{literals.size + 1}".to_sym.tap do |placeholder|
          literals[placeholder] = literal
        end
      end

      def add_subquery(relation)
        subqueries[relation] = Subquery.new(relation, "t#{subqueries.size + 1}")
      end

      def to_sql
        [sql_string(self), literals]
      end

      def select_clause_sql(query)
        select_list.map {|s| s.to_sql(query) }.join(", ")
      end

      def where_clause_sql(query)
        return nil if conditions.empty?
        'where ' + conditions.map do |condition|
          condition.to_sql(query)
        end.join(' and ')
      end

      def from_clause_sql(query)
        table_ref.to_sql(query)
      end

      def rows
        DB[*to_sql]
      end

      def all
        rows.map do |field_values|
          table_ref.build_tuple(field_values)
        end
      end

      protected

      def sql_string(query)
        ["select",
          select_clause_sql(query),
          "from",
          from_clause_sql(query),
          where_clause_sql(query)
        ].compact.join(" ")
      end
    end
  end
end