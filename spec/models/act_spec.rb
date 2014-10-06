# == Schema Information
#
# Table name: acts
#
#  id            :integer          not null, primary key
#  title         :string(255)
#  last_updated  :date
#  jurisdiction  :string(255)
#  updating_acts :text
#  subtitle      :string(255)
#  regulations   :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  act_type      :string(255)
#  year          :integer
#  number        :integer
#

require 'spec_helper'

describe Act do
  before { @act = Act.new(	title: "test Act", 
														last_updated: "2012-12-04", 
														jurisdiction: "Commonwealth", 
														updating_acts: "1 2 4",
														subtitle: "an Act for testing Kai's app",
														regulations: "6",
														act_type: "Act",
														year: 2012,
														number: 16 ) }
	subject { @act }
	
	it { should respond_to(:title) }
	it { should respond_to(:last_updated) }
	it { should respond_to(:jurisdiction) }
	it { should respond_to(:updating_acts) }
	it { should respond_to(:subtitle) }
	it { should respond_to(:regulations) }
	it { should respond_to(:act_type) }
	it { should respond_to(:year) }
	it { should respond_to(:number) }
	it { should respond_to(:containers) }
	it { should respond_to(:comments) }
	
	describe "when title is not present" do
		before { @act.title = " " }
		it { should_not be_valid }
	end
	
	describe "when last_updated is not present" do
		before { @act.last_updated = " " }
		it { should_not be_valid }
	end
	
	describe "when jurisdiction is not present" do
		before { @act.jurisdiction = " " }
		it { should_not be_valid }
	end
	
	describe "when jurisdiction is invalid" do
		before { @act.jurisdiction = "The Moon" }
		it { should_not be_valid }
	end
	
	describe "when act_type is not present" do
		before { @act.act_type = " " }
		it { should_not be_valid }
	end
	
	describe "when year is too low" do
		before { @act.year = 1890 }
		it { should_not be_valid }
	end
	
	describe "when year is too high" do
		before { @act.year = Time.now.year+1 }
		it { should_not be_valid }
	end
	
	describe "when year is valid" do
		before { @act.year = Time.now.year }
		it { should be_valid }
	end
	
	describe "when year is not an integer" do
		before { @act.year = 100.5 }
		it { should_not be_valid }
	end
	
	describe "when number is not present" do
		before { @act.number = " " }
		it { should_not be_valid }
	end
	
	describe "when number is negative" do
		before { @act.number = -1 }
		it { should_not be_valid }
	end
	
	describe "when number is not an integer" do
		before { @act.number = 100.5 }
		it { should_not be_valid }
	end
	
	describe "when act_type is valid" do
		before { @act.act_type = "Act" }
		it { should be_valid }
	end
	
	describe "when act_type is invalid" do
		before { @act.act_type = "Blah" }
		it { should_not be_valid }
	end
	
	describe "sections order and destroying" do
		
		before {@act.save}
		 
		let!(:section_1) do
			FactoryGirl.create(:container, act: @act, number: "1")
		end
		let!(:section_4) do
			FactoryGirl.create(:container, act: @act, number: "4")
		end
		let!(:section_5) do
			FactoryGirl.create(:container, act: @act, number: "5")
		end
		let!(:section_2) do
			FactoryGirl.create(:container, act: @act, number: "2")
		end
		let!(:section_1A) do
			FactoryGirl.create(:container, act: @act, number: "1A")
		end
		
		it "should destroy associated containers" do
			containers = @act.containers.to_a
			@act.destroy
			expect(containers).not_to be_empty
			containers.each do |container|
				expect(Container.where(id: container.id)).to be_empty
			end
		end
	end
	
	
		
end
