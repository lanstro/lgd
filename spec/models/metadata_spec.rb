# == Schema Information
#
# Table name: metadata
#
#  id           :integer          not null, primary key
#  scope_id     :integer
#  scope_type   :string(255)
#  content_id   :integer
#  content_type :string(255)
#  anchor       :string(255)
#  type         :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#

require 'spec_helper'

describe Metadata do
  pending "add some examples to (or delete) #{__FILE__}"
end
