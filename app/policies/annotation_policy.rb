class AnnotationPolicy < ApplicationPolicy
	
	attr_reader :user, :annotation

	def initialize(user, annotation)
		@user        = user
		@annotation  = annotation
	end

	def index?
		user.admin?
	end

	def update?
		user.admin?
	end

	def destroy?
		user.admin?
	end
	
	def create?
		user.admin?
	end

	
  class Scope < Scope
    def resolve
      scope
    end
  end
end
