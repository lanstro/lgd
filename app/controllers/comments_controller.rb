class CommentsController < ApplicationController
	
	# just a json API for the marionette front-end at acts#show
	
  before_filter :authenticate_user!, except: [:index]
	before_filter :ensure_signup_complete, only: [:new, :create, :update, :destroy]
	
	after_filter :verify_authorized, except: [:create, :index]
	before_action :set_and_authorize_comment, except: [:create, :index]
	
	respond_to :json
	
	def create
		error = nil
		if params[:parent_id].to_i > 0
			parent=Comment.find_by_id(params.delete(:parent_id))
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
				format.json { render :json => { success: true, user_id: @comment.user_id, created_at: @comment.created_at, id: @comment.id, message: "Thank you.  Comment added." } }
			elsif error
				format.json { render :json => { success: false, message: error } }
			else
				format.json { render :json => { success: false, message: "Error saving comment. "+@comment.errors.messages.to_s } }
			end
			
		end
		
  end

  def update
		# TODO Medium: finish these other comment functions
		# to finish
  end

  def destroy
		# to finish
  end

  def hide
		# to finish
  end
	
	def index
		container = Container.find_by_id(params[:container_id])
		respond_to do |format|
			if !container
				format.json { render :json => "you must specify the section that the comments are to come from" }
			else
				format.json { render :json => container.comments.to_depth(7).arrange_serializable.to_json }
				# TODO HIGH: option to show rest of tree like reddit
				# make the 7 into a constant somewhere
			end
		end
	end
		
	private
		def set_and_authorize_comment
			@comment=Comment.find_by(id: params[:id])
			authorize @comment
		end
		def comment_params
			params.require(:comment).permit(:content, :container_id)
		end
end
