require 'spec_helper'

describe "Static pages" do
	subject { page }
  describe "Home page" do
		before { visit root_path }
		it { should have_content('Legal Guide Dog') }
		it { should have_title(full_title('')) }
		it { should_not have_title('| Home')}
		it { should have_link('Legislation',    href: acts_path) }
  end
	
  describe "Help page" do
		before { visit help_path }
		it { should have_content('Help') }
		it { should have_title(full_title('Help')) }
  end
	
  describe "About page" do
		before { visit about_path }
		it { should have_content('About Us') }
		it { should have_title(full_title('About Us')) }
  end
	
end