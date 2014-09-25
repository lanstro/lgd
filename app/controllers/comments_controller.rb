class CommentsController < ApplicationController
  
	def index
		# temporary function
		@comments = Comment.all
	end
	
	def new
		@comment = Comment.new(parent_id: params[:parent_id])
	end
	
	def create
		if params[:comment][:parent_id].to_i > 0
			parent=Comment.find_by_id(params[:comment].delete(:parent_id))
			@comment = parent.children.build(comment_params)
			@comment.container_id = parent.container_id
		else
			# TODO HIGH - change to right container
			@comment = Comment.new(comment_params)
			@comment.container_id=5
		end
		@comment.user = current_user
		if @comment.save
			flash[:success] = 'Your comment was successfully added!'
			redirect_to comments_path
		else
			# flash error messages
			render 'new'
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
	
	private

	def comment_params
		params.require(:comment).permit(:content)
	end
end
