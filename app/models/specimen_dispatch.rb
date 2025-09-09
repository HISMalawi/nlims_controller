# frozen_string_literal: true

# # This is the model for the specimen dispatch table
class SpecimenDispatch < ApplicationRecord
  belongs_to :specimen_dispatch_types, class_name: 'SpecimenDispatchType', foreign_key: 'dispatcher_type_id'
end
