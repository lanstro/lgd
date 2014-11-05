# == Schema Information
#
# Table name: flags
#
#  id             :integer          not null, primary key
#  category       :string(255)
#  user_id        :integer
#  flaggable_id   :integer
#  flaggable_type :string(255)
#  comment        :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#

require 'spec_helper'

describe Flag do
  pending "add some examples to (or delete) #{__FILE__}"
end
