# == Schema Information
#
# Table name: annotations
#
#  id           :integer          not null, primary key
#  metadatum_id :integer
#  container_id :integer
#  anchor       :string(255)
#  position     :integer
#  created_at   :datetime
#  updated_at   :datetime
#  category     :string(255)
#
# Indexes
#
#  annotation_uniqueness  (anchor,container_id,metadatum_id,position) UNIQUE
#

require 'spec_helper'

describe Annotation do
  pending "add some examples to (or delete) #{__FILE__}"
end
