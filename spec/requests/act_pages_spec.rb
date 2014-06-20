require 'spec_helper'

describe "ActPages" do
  
	subject {page}
	
	describe "admin tasks without permission" do 
		
		let(:user) { FactoryGirl.create(:user) }
		let(:act)  { FactoryGirl.create(:act) }
		
		describe "visiting act creation page" do
			before { sign_in user }
			before { visit new_act_path }
			
			describe "should go to home page" do
				it {should have_content("I'm the Legal Guide Dog")}
			end
		end
		
		describe "visiting edit page" do
			before { sign_in user }
			before { visit edit_act_path(act) }
			
			describe "should go to home page" do
				it {should have_content("I'm the Legal Guide Dog")}
			end
		end
		
		describe "using http actions on act creation and edit" do
			before { sign_in user, no_capybara: true }
			let(:act) { FactoryGirl.create(:act) }
			
			describe "attempting to GET edit path" do
				before { get edit_act_path(act) }
				
				specify { expect(response.body).not_to match(full_title('Edit Act')) }
				specify { expect(response).to redirect_to(root_url) }
			end
			
			describe "attempting to edit an act" do
				before do 
					act.title="new title"
					patch act_path(act)
				end
				specify { expect(response).to redirect_to(root_url) }
			end
			
			describe "attempting to delete an act" do
				before { delete act_path(act) }
				specify { expect(response).to redirect_to(root_url) }
			end
			
			describe "trying to create a new act" do
				
				let (:params) do  
					{act: FactoryGirl.attributes_for(:act) }
				end
				before { post acts_path, params }
				specify { expect(response).to redirect_to(root_url) }
			end
		end
	end
	
	describe "admin tasks with admin" do
		
		let(:user) { FactoryGirl.create(:user, admin: true) }
		before { sign_in user }
		
		describe "visiting act creation page" do
			before { visit new_act_path }
			
			describe "should have the creation form as admin" do
				it {should have_content("Instrument Type")}
				it {should have_selector("input")}
			end
			
			describe "creating a new act" do
				
				before do
					fill_in "Title",           with: "Test title"
					fill_in "Subtitle",        with: "Test subtitle"
					select "Commonwealth",     from: "Jurisdiction"
					select "Act",              from: "Instrument Type"
					fill_in "Year",            with: 1997
					fill_in "Number",          with: 10
				end
				it "should create an Act" do
					expect { click_button "Create new act" }.to change(Act, :count).by(1)
				end
				
				describe "after saving the act" do
					before { click_button "Create new act" }
					let(:act) { Act.find_by(title: "Test title") }
					
					it { should have_title(act.title) }
					it { should have_selector('div.alert.alert-success', text: 'act created') }
				end
				
			end
			
			describe "editing an act" do
				let(:act) { FactoryGirl.create(:act) }
				before { visit edit_act_path(act) }
				describe "page" do
					it { should have_content("Updating legislation:") }
					it { should have_title("Edit Legislation") }
				end
				describe "with invalid information" do
					before do
						fill_in "Number",              with: -5
						click_button "Save changes"
					end
					it { should have_content('error') }
				end
				describe "with valid information" do
					before do
						fill_in "Title",             with: "New Title"
						fill_in "Number",            with: 13
						click_button "Save changes"
					end
					
					it { should have_title("New Title") }
					it { should have_selector('div.alert.alert-success') }
					specify { expect(act.reload.title).to  eq "New Title" }
					specify { expect(act.reload.number).to eq 13 }
				end
				
			end
		end
		
  end
	
	describe "visiting index page" do
		
		before { visit acts_path }
		
		it { should have_title('All legislation') }
    it { should have_content('Index of legislation') }
		
    describe "pagination" do
			
      before(:all) { 30.times { FactoryGirl.create(:act) } }
      after(:all)  { Act.delete_all }
			
      it "should list each act" do
        Act.paginate(page: 1).each do |act|
          expect(page).to have_selector('li', text: act.title)
        end
      end
    end
		
    describe "new, delete and edit links" do
			
      before(:all) { 10.times { FactoryGirl.create(:act) } }
      after(:all)  { Act.delete_all }
			
      it { should_not have_link('delete') }
			it { should_not have_link('Create new legislation') }
			
      describe "as an admin user" do
        let(:admin) { FactoryGirl.create(:admin) }
        before do
          sign_in admin
          visit acts_path
        end
				
        it { should have_link('delete', href: act_path(Act.first)) }
				it { should have_link('edit', href: edit_act_path(Act.first)) }
				it { should have_link('Create new legislation', href: new_act_path) }
        it "should be able to delete an Act" do
          expect do
            click_link('delete', match: :first)
          end.to change(Act, :count).by(-1)
        end
				describe "clicking an edit link should go to the act's edit page" do
					before { click_link('edit', match: :first) }
					it { should have_title("Edit Legislation") }
					it { should have_content("Updating legislation:") }
				end
      end
    end
		
		
	end
	
end