class CommentPolicy < ApplicationPolicy
	
	attr_reader :user, :comment

	def initialize(user, comment)
		@user     = user
		@comment  = comment
	end
	
	def edit?
		user.admin? or comment.user == user
	end
	
	def update?
		user.admin? or comment.user == user
	end
	
	def destroy?
		user.admin?
	end
	
	def hide?
		user.admin?
	end
	
  class Scope < Scope
    def resolve
      scope
    end
  end
end
