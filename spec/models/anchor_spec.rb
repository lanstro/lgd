require 'spec_helper'

describe Anchor do
	
	let (:container) { FactoryGirl.create(:container) }
	
  before { @anchor = container.anchors.build(
					   anchor_text: "defined term"
	
						)}
	subject { @anchor }
	
	it { should respond_to(:anchor_text) }
	it { should respond_to(:container) }
	it { should respond_to(:metadata) }
	 
end
