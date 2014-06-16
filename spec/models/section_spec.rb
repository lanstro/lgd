require 'spec_helper'
require 'factory_girl' 

describe Section do
  
	let(:act) { FactoryGirl.create(:act) }
	
	before { @section = act.sections.build( number: "2A",
																					last_updated: "2013-07-12",
																					title: "Test",
																					updating_acts: "1 2 4",
																					section_type: "Regulation",
																					regulations: 6) }
	
	subject { @section }
	 
	
	it { should respond_to(:act) }
	it { should respond_to(:number) }
	it { should respond_to(:last_updated) }
	it { should respond_to(:updating_acts) }
	it { should respond_to(:title) }
	it { should respond_to(:regulations) }
	it { should respond_to(:section_type) }
	its(:act) {should eq act}
	
	describe "when no owning act" do
		before {@section.act_id=nil}
		it {should_not be_valid}
	end
	
	describe "owning act should exist" do
		before {@section.act_id=10000000000 }
		it {should_not be_valid}
	end
	
	describe "when no section number" do
		before {@section.number=" "}
		it {should_not be_valid}
	end
	
	describe "when no section_type" do
		before {@section.section_type=" "}
		it {should_not be_valid}
	end
	
	describe "when section_type is invalid" do
		before {@section.section_type="lawl"}
		it {should_not be_valid}
	end
	
	describe "when section_type is valid" do
		before {@section.section_type="Regulation"}
		it {should be_valid}
	end
end
