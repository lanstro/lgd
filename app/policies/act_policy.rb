class ActPolicy < ApplicationPolicy
	
	attr_reader :user, :act

	def initialize(user, act)
		@user = user
		@act  = act
	end
	

	def new?
		user.admin?
	end

	def create?
		user.admin?
	end

	def edit?
		user.admin?
	end

	def update?
		user.admin?
	end
	
	def destroy?
		user.admin?
	end

	def parse?
		user.admin?
	end

	def reset_parsing?
		user.admin?
	end

	def publish?
		user.admin?
	end

	def unpublish?
		user.admin?
	end
	
	
  class Scope < Scope
    def resolve

			def initialize(user, scope)
				@user = user
				@scope = scope
			end
			
			def resolve
				if user.admin?
					scope.all
				else
					scope.where(published: true)
				end
			end
      
    end
  end
end
