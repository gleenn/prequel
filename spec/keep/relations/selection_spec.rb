require 'spec_helper'

module Keep
  module Relations
    describe Selection do
      before do
        class Blog < Keep::Record
          column :id, :integer
          column :user_id, :integer
        end
      end

      describe "#initialize" do
        it "resolves symbols in the selection's predicate to columns derived from the selection's operand, not the selection itself" do
          selection = Blog.where(:user_id => 1)
          selection.predicate.left.should == Blog.table.get_column(:user_id)
        end
      end

      describe "#to_sql" do
        describe "a selection on a table" do
          it "generates the appropriate SQL" do
            Blog.where(:user_id => 1).to_sql.should be_like_query(%{
              select * from blogs where blogs.user_id = :v1
            }, :v1 => 1)
          end
        end
      end
    end
  end
end
