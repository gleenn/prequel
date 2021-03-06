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

    describe "class methods" do
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
            DB[:blogs] << {:id => 1}
          end

          it "gives records a method that finds the associated record" do
            Post.belongs_to(:blog)
            post = Post.new(:blog_id => 1)
            post.blog.should == Blog.find(1)

            post.blog_id = 99
            post.blog.should be_nil
          end

          it "accepts a class name option" do
            Post.belongs_to(:my_blog, :class_name => "Blog")
            post = Post.new(:blog_id => 1)
            post.my_blog.should == Blog.find(1)
          end
        end
      end

      describe ".new(field_values)" do
        it "returns a record with the same id from the identity map if it exists" do
          Blog.create_table
          DB[:blogs] << {:id => 1, :title => "Blog 1"}

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

      describe ".create(attributes)" do
        before do
          Blog.create_table
        end

        it "builds and saves an instance, sets its id, and ensures it is present in the session's identity map" do
          blog = Blog.create(:title => "My Blog!")
          blog.id.should_not be_nil
          blog.should equal(Blog.find(blog.id))
        end
      end

      describe ".secure_create(attributes)" do
        before do
          class ::Blog < Record
            column :subtitle, :string
            column :user_id, :integer

            def create_whitelist
              [:subtitle, :title, :user_id]
            end

            def create_blacklist
              [:user_id]
            end
          end

          Blog.create_table
        end

        it "only allows attributes that are on the create whitelist and not on the create blacklist to be assigned" do
          blog = Blog.secure_create(:title => "The Chefanies", :subtitle => "Exploring Deliciousness", :user_id => 4)
          blog.id.should_not be_nil

          blog.title.should == "The Chefanies"
          blog.subtitle.should == "Exploring Deliciousness"
          blog.user_id.should be_nil
        end

        it "if can_create? returns false, and does not create the record and returns false" do
          class ::Blog
            def can_create?
              false
            end
          end

          expect {
            Blog.secure_create(:title => "Hola!").should be_false
          }.should_not change(Blog, :count)
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


    describe "#reload(columns = nil)" do
      attr_reader :blog

      before do
        class ::Blog < Record
          column :user_id, :integer
          column :subtitle, :string
        end
        Blog.create_table
        @blog = Blog.create(:title => "Title 1", :subtitle => "Subtitle 1", :user_id => 1)
      end

      context "when not passed any columns" do
        it "reloads the record and marks it clean" do
          blog.soft_update(:title => "Dirty Title", :subtitle => "Dirty Subtitle", :user_id => 99)
          blog.should be_dirty

          blog.reload

          blog.should be_clean
          blog.title.should == "Title 1"
          blog.subtitle.should == "Subtitle 1"
          blog.user_id.should == 1

          DB[:blogs].update(:title => "Title 2", :subtitle => "Subtitle 2", :user_id => 100)
          blog.reload

          blog.should be_clean
          blog.title.should == "Title 2"
          blog.subtitle.should == "Subtitle 2"
          blog.user_id.should == 100
        end
      end

      context "when passed columns" do
        it "reloads only the given columns and marks them clean" do
          blog.soft_update(:title => "Dirty Title", :subtitle => "Dirty Subtitle", :user_id => 99)
          blog.should be_dirty

          blog.reload(:title, :subtitle)

          blog.dirty_field_values.keys.should == [:user_id]
          blog.title.should == "Title 1"
          blog.subtitle.should == "Subtitle 1"
          blog.user_id.should == 99
        end
      end
    end

    describe "#save" do
      attr_reader :blog

      before do
        Blog.column :user_id, :integer
        Blog.create_table
        @blog = Blog.new({:title => "Unsaved Blog", :user_id => 1})
        blog.id.should be_nil
      end

      describe "when the record has not yet been inserted into the database" do
        it "inserts the record, sets its id, and ensures it is present in the session's identity map" do
          blog.save
          blog.id.should_not be_nil
          DB[:blogs].filter(:id => blog.id).first.should == blog.field_values
          blog.should equal(Blog.find(blog.id))
        end

        it "executes before_create and after_create hooks at the appropriate moments" do
          mock(blog).before_create { blog.id.should be_nil }
          mock(blog).after_create { blog.id.should_not be_nil }
          blog.save
        end

        it "executes before_save and after_save hooks at the appropriate moments" do
          mock(blog).before_save { blog.id.should be_nil }
          mock(blog).after_save { blog.id.should_not be_nil }
          blog.save
        end
      end

      describe "when the record has already been inserted into the database" do
        before do
          blog.save
          blog.id.should_not be_nil
        end

        it "saves only the fields that are dirty back into the database" do
          blog.title = "New Title"
          DB[:blogs].filter(:id => blog.id).update(:user_id => 2)
          blog.user_id.should == 1

          blog.save

          DB[:blogs].count.should == 1
          DB[:blogs].filter(:id => blog.id).first.should == {
            :id => blog.id,
            :title => "New Title",
            :user_id => 2
          }
        end
      end
    end

    describe "#update and #secure_update" do
      attr_reader :blog
      before do
        class ::Blog
          column :user_id, :integer
          column :subtitle, :string

          def tricky_subtitle=(subtitle)
            self.subtitle = "Tricky #{subtitle}"
          end

          create_table
        end
        @blog = Blog.create({:title => "Saved Blog", :user_id => 1})
      end

      describe "#update(attributes)" do
        it "assigns all attributes and saves the record" do
          blog.update(:title => "Coding For Fun", :tricky_subtitle => "And Maybe Eventually Profit?", :user_id => 4)

          DB[:blogs].find(blog.id).first.should == {
            :id => blog.id,
            :title => "Coding For Fun",
            :subtitle => "Tricky And Maybe Eventually Profit?",
            :user_id => 4
          }
        end
      end

      describe "#secure_update(attributes)" do
        it "only allows whitelisted attributes to be assigned" do
          stub(blog).update_whitelist { [:title, :subtitle] }
          stub(blog).update_blacklist { [:title] }

          blog.secure_update(:title => "Coding For Fun", :subtitle => "And Maybe Eventually Profit?", :user_id => 4)
          DB[:blogs].find(blog.id).first.should == {
            :id => blog.id,
            :title => "Saved Blog",
            :subtitle => "And Maybe Eventually Profit?",
            :user_id => 1
          }
        end

        it "if can_update? returns false does not perform the update and returns false" do
          stub(blog).can_update? { false }
          blog.secure_update(:title => "Coding For Fun", :subtitle => "And Maybe Eventually Profit?").should be_false
          DB[:blogs].find(blog.id).first.should == {
            :id => blog.id,
            :title => "Saved Blog",
            :subtitle => nil,
            :user_id => 1
          }
          

          stub(blog).can_update? { true }
        end
      end
    end

    describe "#destroy and #secure_destroy" do
      attr_reader :blog
      before do
        Blog.create_table
        @blog = Blog.create
      end

      describe "#destroy" do
        it "removes the record from the database and the identity map" do
          blog.destroy
          Blog.find(blog.id).should be_nil
          Prequel.session[:blogs][blog.id].should be_nil
        end
      end

      describe "#secure_destroy" do
        it "if can_destroy? returns false, returns false and does not destroy the record" do
          stub(blog).can_destroy? { false }
          blog.secure_destroy
          Blog.find(blog.id).should == blog
          Prequel.session[:blogs][blog.id].should == blog
        end
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
        it "returns all field values that are on the #read_whitelist and not on the black list, with stringified keys" do
          blog = Blog.new(:title => "My Blog")
          blog.wire_representation.should == {
            'id' => nil,
            'lucky_number' => 7,
            'title' => "My Blog"
          }

          stub(blog).read_whitelist { [:id, :lucky_number] }
          blog.wire_representation.should == {
            'id' => nil,
            'lucky_number' => 7,
          }

          stub(blog).read_blacklist { [:lucky_number] }
          blog.wire_representation.should == {
            'id' => nil
          }
        end
      end
    end

    describe "clean vs. dirty state" do
      before do
        Blog.create_table
      end

      specify "a record is dirty before it has been saved for the first time and clean thereafter" do
        blog = Blog.new(:title => "Hello there")
        blog.should be_dirty
        blog.save
        blog.should be_clean
      end

      specify "a record is clean when it is freshly retrieved from the database, dirty after local modifications, and clean again after being saved" do
        DB[:blogs] << {:id => 1, :title => "Hi!"}
        DB[:blogs] << {:id => 2, :title => "Ho!"}
        blog = Blog.find(1)
        blog.should be_clean

        Blog.all.each do |blog|
          blog.should be_clean
        end

        blog.title = "Bye!"
        blog.should be_dirty
        blog.save
        blog.should be_clean
      end
    end
  end
end
