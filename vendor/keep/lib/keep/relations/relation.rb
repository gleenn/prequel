module Keep
  module Relations
    class Relation
      delegate :to_sql, :result_set, :all, :first, :to => :query

      def query
        Sql::Query.new(self).build
      end

      def find(id)
        where(:id => id).first
      end

      def where(predicate)
        Selection.new(self, predicate)
      end

      def join(right, predicate)
        InnerJoin.new(self, right, predicate)
      end

      def project(*symbols)
        Projection.new(self, *symbols)
      end

      def table_ref(query)
        singular_table_ref(query)
      end

      def singular_table_ref(query)
        query.add_subquery(self)
      end

      def to_relation
        self
      end

      protected
      def derived_columns
        @derive_columns ||= {}
      end

      def derive_column_from(operand, name, alias_name=nil)
        column = operand.get_column(name)
        derive_column(column, alias_name) if column
      end

      def derive_column(column, alias_name=nil)
        derived_columns[column] ||= Expressions::DerivedColumn.new(self, column, alias_name)
      end
    end
  end
end