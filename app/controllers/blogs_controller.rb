class BlogsController < ApplicationController

  before_filter :find_blog, :only => ['comment', 'show', 'authorize']
  before_filter :find_page, :except => ['captcha', 'authorize']
  before_filter :load_blogs, :except => ['captcha', 'authorize', 'tag', 'category', 'author', 'show']
  before_filter :load_tags, :except => ['captcha', 'authorize']

  def index
    present(@page)
    
    respond_to do |format|
        format.html
        format.rss
    end
  end
  
  def tag
    @blogs = Blog.tagged_with(params[:tag], :on => :tags).published
    present(@page)
    render 'index'
  end

  def category
    @blogs = Blog.tagged_with(params[:category], :on => :categories).published
    present(@page)
    render 'index'
  end

  def author
    @blogs = Blog.tagged_with(params[:author], :on => :authors).published
    present(@page)
    render 'index'
  end



  def show
    if @blog
      @comment = @blog.comments.new
      present(@page)
    else
      error_404
    end
  end
  
  def comment
    @comment = @blog.comments.new(params[:comment])
    
    if Raptcha.valid?(params) || BlogSetting.enable_captcha == false
      @comment.approved = true unless BlogSetting.manual_moderation
      if @comment.save
        flash[:notice] = "Comment was posted successfully! Waiting for approval!"
        @message = @page[:successful_comment]
        if BlogSetting.enable_email_notification
          begin
            BlogMailer.deliver_notification(@comment, request)
          rescue
            logger.warn "There was an error delivering a blog notification.\n#{$!}\n"
          end
        end
        if BlogSetting.enable_approve_comment_by_email && BlogSetting.manual_moderation
          begin
            BlogMailer.deliver_confirmation(@comment, request)
          rescue
            logger.warn "There was an error delivering a blog confirmation.\n#{$!}\n"
          end
        end
        @comment = @blog.comments.new
      end
    else
      @message = @page[:invalid_comment]
    end
    
    present(@page)
    render 'show'
  end
  
  def captcha
    Raptcha.render(controller=self, params)
  end
  
  def authorize
    if params[:token] && BlogSetting.enable_approve_comment_by_email && BlogSetting.manual_moderation
      @comment = Comment.find_by_token(params[:token])
      @comment.approved = true
      redirect_to blog_post_url(@comment.blog.permalink) if @comment.save 
    else
      redirect_to blog_url
    end
  end

protected
  def load_blogs
    @blogs = Blog.published
    @recent_blogs = Blog.published(:limit => 5) if BlogSetting.enable_recent_blogs
  end
  
  def find_blog
    if @blog = Blog.find_by_permalink(params[:permalink], :conditions => ["publishing_date < ? and draft = false", Time.now])
      @related_tags_blogs = @blog.find_related_tags if BlogSetting.enable_related_tags
      @related_categories_blogs = @blog.find_related_categories if BlogSetting.enable_related_categories
      @related_authors_blogs = @blog.find_related_authors if BlogSetting.enable_related_authors
      @recent_blogs = Blog.find(:all, :limit => 5, :conditions => ["id != ? and publishing_date < ? and draft = false", Blog.first, Time.now]) if BlogSetting.enable_recent_blogs
    end
  end
  
  def load_tags
    @tags = Blog.published.tag_counts if BlogSetting.enable_tags
    @categories = Blog.published.category_counts if BlogSetting.enable_categories
    @authors = Blog.published.author_counts if BlogSetting.enable_authors
  end

  def find_page
    @page = Page.find_by_link_url("/blog")
  end  
end
