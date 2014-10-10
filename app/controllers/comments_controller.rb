class CommentsController < ApplicationController
  before_filter :authenticate_user!, except: [:get_comments_by_container]
	before_filter :ensure_signup_complete, only: [:new, :create, :update, :destroy]
	
	def index
		# temporary function
		@comments = Comment.all
	end
	
	def new
		@comment = Comment.new(parent_id: params[:parent_id])
	end
	
	def create
		error = nil
		if params[:comment][:parent_id].to_i > 0
			parent=Comment.find_by_id(params[:comment].delete(:parent_id))
			if parent
				@comment = parent.children.build(comment_params)
				@comment.container_id = parent.container_id
			else
				error = "Error posting comment: the comment being replied to does not exist."
			end
		else
			# container_id should be part of the params
			@comment = Comment.new(comment_params)
		end
		@comment.user = current_user
		
		respond_to do |format|
			if !error and @comment.save
				format.json { render :json => { success: true, message: "Thank you.  Comment added." } }
			elsif error
				format.json { render :json => { success: false, message: error } }
			else
				format.json { render :json => { success: false, message: "Error saving comment. "+@comment.errors.messages.to_s } }
			end
			
		end
		
  end

  def edit
  end

  def update
  end

  def destroy
  end

  def hide
  end
	
	def get_comments_by_container
		container = Container.find_by_id(params[:container_id])
		
		respond_to do |format|
			if !container
				format.json { render :json => "no such section" }
			else
				format.json { render :json => container.comments.to_depth(7).arrange_serializable.to_json }
			end
			# TODO HIGH: option to show rest of tree like reddit
			# make the 7 into a constant somewhere
		end
	end
	
	private

	def comment_params
		params.require(:comment).permit(:content, :container_id)
	end
end
