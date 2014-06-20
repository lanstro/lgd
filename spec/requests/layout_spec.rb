require 'spec_helper'

describe "layouts" do
	subject { page }
	
	describe "layout for admin" do
		let(:user) { FactoryGirl.create(:user, admin: true )}
		before { sign_in user }
		describe "Header" do
			it { should have_link("Legislation", href: acts_path ) }
			it { should have_link("Users", href: users_path ) }
		end
	end
	
	describe "layout for normal users" do
		let(:user) { FactoryGirl.create(:user)}
		before { sign_in user }
		describe "Header" do
			it { should have_link("Legislation", href: acts_path ) }
			it { should_not have_link("Users", href: users_path ) }
		end
	end
	
	describe "layout for everyone" do
		before { visit root_path }
		describe "Header" do
			it { should have_link("Legislation", href: acts_path ) }
		end
	end
end