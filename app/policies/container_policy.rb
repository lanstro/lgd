class ContainerPolicy < ApplicationPolicy
	
	attr_reader :user, :container

	def initialize(user, container)
		@user       = user
		@container  = container
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
	
  class Scope < Scope
    def resolve
      scope
    end
  end
end
