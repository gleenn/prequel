require 'spec_helper'

module Prequel
  module Relations
    describe InnerJoin do
      before do
        class Blog < Prequel::Record
          column :id, :integer
          column :user_id, :integer
          column :title, :string
        end

        class Post < Prequel::Record
          column :id, :integer
          column :blog_id, :integer
          column :title, :string
        end

        class Comment < Prequel::Record
          column :id, :integer
          column :post_id, :integer
          column :body, :string
        end
      end

      describe "#initialize" do
        it "resolves symbols in the join's predicate to columns derived from the join's operands, not the join itself" do
          simple_join = Blog.left_join(Post, Blog[:id] => Post[:blog_id])
          simple_join.predicate.left.should == Blog.table.get_column(:id)
          simple_join.predicate.right.should == Post.table.get_column(:blog_id)

          compound_join = simple_join.left_join(Comment, Post[:id] => Comment[:post_id])
          compound_join.predicate.left.should == simple_join.get_column(Post[:id])
          compound_join.predicate.right.should == Comment.table.get_column(:post_id)
        end
      end

      describe "#all" do
        before do
          Blog.create_table
          Post.create_table
          Comment.create_table

          DB[:blogs] << { :id => 1, :user_id => 1, :title => "Blog 1" }
          DB[:blogs] << { :id => 2, :user_id => 2, :title => "Blog 2" }
          DB[:posts] << { :id => 1, :blog_id => 1, :title => "Blog 1, Post 1" }
          DB[:posts] << { :id => 2, :blog_id => 1, :title => "Blog 1, Post 2" }
          DB[:posts] << { :id => 3, :blog_id => 2, :title => "Blog 2, Post 1" }
          DB[:comments] << { :id => 1, :post_id => 1, :body => "Post 1 comment." }
          DB[:comments] << { :id => 2, :post_id => 2, :body => "Post 2 comment." }
        end

        describe "when there are no matching tuples on the right" do
          it "returns composite tuples that contain the left records without the right" do
            relation = Blog.left_join(Post, Blog[:id] => :blog_id).left_join(Comment, Post[:id] => :post_id)
            blogs_posts_comments = relation.all
            blogs_posts_comments.size.should == 3

            blogs_posts_comments[0][:blogs].should == Blog.find(1)
            blogs_posts_comments[0][:posts].should == Post.find(1)
            blogs_posts_comments[0][:comments].should == Comment.find(1)

            blogs_posts_comments[1][:blogs].should == Blog.find(1)
            blogs_posts_comments[1][:posts].should == Post.find(2)
            blogs_posts_comments[1][:comments].should == Comment.find(2)

            blogs_posts_comments[2][:blogs].should == Blog.find(2)
            blogs_posts_comments[2][:posts].should == Post.find(3)
            blogs_posts_comments[2][:comments].should be_nil
          end
        end
      end

      describe "#to_sql" do
        describe "a simple left join" do
          it "generates appropriate sql, aliasing select list columns to their fully qualified names" do
            Blog.left_join(Post, Blog[:id] => :blog_id).to_sql.should be_like_query(%{
              select
                blogs.id as blogs__id,
                blogs.user_id as blogs__user_id,
                blogs.title as blogs__title,
                posts.id as posts__id,
                posts.blog_id as posts__blog_id,
                posts.title as posts__title
              from
                blogs left outer join posts on blogs.id = posts.blog_id
            })
          end
        end

        describe "a left join containing a subquery" do
          it "generates appropriate sql, aliasing columns to their qualified names and correctly referencing columns derived from the subquery" do
            Blog.where(:user_id => 1).left_join(Post, Blog[:id] => :blog_id).to_sql.should be_like_query(%{
              select
                t1.id as t1__id,
                t1.user_id as t1__user_id,
                t1.title as t1__title,
                posts.id as posts__id,
                posts.blog_id as posts__blog_id,
                posts.title as posts__title
              from (
                  select *
                  from blogs
                  where blogs.user_id = :v1
                ) as t1
                left outer join posts on t1.id = posts.blog_id
              }, :v1 => 1)
          end
        end

        describe "a left-associative 3-table left join with a subquery" do
          it "generates the appropriate sql" do
            Blog.where(:user_id => 1).left_join(Post, Blog[:id] => :blog_id).left_join(Comment, Post[:id] => :post_id).to_sql.should be_like_query(%{
              select
                t1.id as t1__id,
                t1.user_id as t1__user_id,
                t1.title as t1__title,
                posts.id as posts__id,
                posts.blog_id as posts__blog_id,
                posts.title as posts__title,
                comments.id as comments__id,
                comments.post_id as comments__post_id,
                comments.body as comments__body
              from
                (
                  select *
                  from blogs
                  where blogs.user_id = :v1
                ) as t1
                left outer join posts on t1.id = posts.blog_id
                left outer join comments on posts.id = comments.post_id
              }, :v1 => 1)
          end
        end

        describe "a right-associative 3-table inner join, with subqueries on either side" do
          it "generates the appropriate sql" do
            posts_comments = Post.left_join(Comment, Post[:id] => :post_id)
            rel = Blog.where(:user_id => 1).left_join(posts_comments, Blog[:id] => :blog_id)

            rel.to_sql.should be_like_query(%{
              select t1.id                as t1__id,
                     t1.user_id           as t1__user_id,
                     t1.title             as t1__title,
                     t2.posts__id         as t2__posts__id,
                     t2.posts__blog_id    as t2__posts__blog_id,
                     t2.posts__title      as t2__posts__title,
                     t2.comments__id      as t2__comments__id,
                     t2.comments__post_id as t2__comments__post_id,
                     t2.comments__body    as t2__comments__body
              from   (select *
                      from   blogs
                      where  blogs.user_id = :v1) as t1
                     left outer join (select posts.id         as posts__id,
                                        posts.blog_id    as posts__blog_id,
                                        posts.title      as posts__title,
                                        comments.id      as comments__id,
                                        comments.post_id as comments__post_id,
                                        comments.body    as comments__body
                                 from   posts
                                        left outer join comments
                                          on posts.id = comments.post_id) as t2
                       on t1.id = t2.posts__blog_id
            }, :v1 => 1)
          end
        end

        describe "a left join containing a projection within a subquery" do
          it "generates sql with the selection predicate correctly refering to columns from the join" do
            posts_comments = Post.left_join(Comment, Post[:id] => :post_id)
            Blog.left_join(posts_comments.project(Post), Blog[:id] => :blog_id).where(Post[:title] => "Post Title").to_sql.should be_like_query(%{
              select blogs.id      as blogs__id,
                     blogs.user_id as blogs__user_id,
                     blogs.title   as blogs__title,
                     t1.id         as t1__id,
                     t1.blog_id    as t1__blog_id,
                     t1.title      as t1__title
              from   blogs
                     left outer join (select posts.id      as id,
                                        posts.blog_id as blog_id,
                                        posts.title   as title
                                 from   posts
                                        left outer join comments
                                          on posts.id = comments.post_id) as t1
                       on blogs.id = t1.blog_id
              where  t1.title = :v1
            }, :v1 => "Post Title")
          end
        end
      end
    end
  end
end
