require 'spec_helper'

describe Metadata do
  before { @metadata = Anchor.new(
		anchor="defined term"
		
					)}
	subject { @metadata }
	
	it { should respond_to(:anchor) }
end
