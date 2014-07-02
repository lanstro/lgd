require 'spec_helper'
require 'factory_girl' 

describe Container do
  
	let(:act) { FactoryGirl.create(:act) }
	
	before { @container = act.containers.build( number: "2A",
																					last_updated: "2013-07-12",
																					title: "Test",
																					updating_acts: "1 2 4",
																					container_type: "Regulation",
																					regulations: 6) }
	
	subject { @container }
	 
	
	it { should respond_to(:act) }
	it { should respond_to(:number) }
	it { should respond_to(:last_updated) }
	it { should respond_to(:updating_acts) }
	it { should respond_to(:title) }
	it { should respond_to(:regulations) }
	it { should respond_to(:container_type) }
	its(:act) {should eq act}
	
	describe "when no owning act" do
		before {@container.act_id=nil}
		it {should_not be_valid}
	end
	
	describe "owning act should exist" do
		before {@container.act_id=10000000000 }
		it {should_not be_valid}
	end
	
	describe "when no container number" do
		before {@container.number=" "}
		it {should_not be_valid}
	end
	
	describe "when no container_type" do
		before {@container.container_type=" "}
		it {should_not be_valid}
	end
	
	describe "when container_type is invalid" do
		before {@container.container_type="lawl"}
		it {should_not be_valid}
	end
	
	describe "when container_type is valid" do
		before {@container.container_type="Regulation"}
		it {should be_valid}
	end
end
