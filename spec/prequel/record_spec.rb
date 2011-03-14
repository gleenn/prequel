require 'spec_helper'

module Prequel
  describe Record do
    before do
      class ::Blog < Record
        column :id, :integer
        column :title, :string
      end
    end

    describe "when it is subclassed" do
      specify "the subclass gets associated with a table" do
        Blog.table.name.should == :blogs
        Blog.table.tuple_class.should == Blog
      end

      specify "accessor methods are assigned on the subclass for columns on the table" do
        b = Blog.new
        b.title = "Title"
        b.title.should == "Title"
      end
    end

    describe ".new(field_values)" do
      it "returns a record with the same id from the identity map if it exists" do
        Blog.create_table
        DB[:blogs] << { :id => 1, :title => "Blog 1" }

        blog = Blog.find(1)
        blog.id.should == 1
        Blog.find(1).should equal(blog)

        stub(Prequel).session { Session.new }
        
        Blog.find(1).should_not equal(blog)
      end

      it "does not attempt to store records with no id in the identity map" do
        Blog.new.should_not equal(Blog.new)
      end
    end

    describe "relation macros" do
      before do
        class ::Post < Record
          column :id, :integer
          column :blog_id, :integer
        end
      end

      describe ".has_many(name)" do
        it "gives records a one-to-many relation to the table with the given name" do
          Blog.has_many(:posts)
          blog = Blog.new(:id => 1)
          blog.posts.should == Post.where(:blog_id => 1)
        end

        it "accepts a class name" do
          Blog.has_many(:posts_with_another_name, :class_name => "Post")
          blog = Blog.new(:id => 1)
          blog.posts_with_another_name.should == Post.where(:blog_id => 1)
        end

        it "accepts an order by option" do
          Blog.has_many(:posts, :order_by => :id)
          blog = Blog.new(:id => 1)
          blog.posts.should == Post.where(:blog_id => 1).order_by(:id)

          Blog.has_many(:posts, :order_by => [:id, :blog_id.desc])
          blog.posts.should == Post.where(:blog_id => 1).order_by(:id, :blog_id.desc)
        end
      end

      describe ".belongs_to(name)" do
        before do
          Blog.create_table
          DB[:blogs] << { :id => 1 }
        end

        it "gives records a method that finds the associated record" do
          Post.belongs_to(:blog)
          post = Post.new(:blog_id => 1)
          post.blog.should == Blog.find(1)
        end

        it "accepts a class name option" do
          Post.belongs_to(:my_blog, :class_name => "Blog")
          post = Post.new(:blog_id => 1)
          post.my_blog.should == Blog.find(1)
        end
      end
    end

    describe "#initialize" do
      it "honors default values from the table's column declarations, if they aren't specified in the attributes" do
        Blog.column :title, :string, :default => "New Blog"
        Blog.new.title.should == "New Blog"
        Blog.new(:title => "My Blog").title.should == "My Blog"
      end
    end

    describe "methods that return field values" do
      before do
        class ::Blog
          Blog.synthetic_column :lucky_number, :integer

          def lucky_number
            7
          end
        end
      end

      describe "#field_values" do
        it "returns the real and synthetic field values as a hash" do
          blog = Blog.new(:title => "My Blog")
          blog.field_values.should == {
            :id => nil,
            :lucky_number => 7,
            :title => "My Blog"
          }
        end
      end

      describe "#wire_representation" do
        it "returns all field values that are on the #read_white_list and not on the black list, with stringified keys" do
          pending
          blog = Blog.new(:title => "My Blog")
          blog.wire_representation.should == {
            'id' => nil,
            'lucky_number' => 7,
            'title' => "My Blog"
          }
        end
      end
    end
  end
end
