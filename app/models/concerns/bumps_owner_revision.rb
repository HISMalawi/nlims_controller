# frozen_string_literal: true

# Links and ranges have no revision of their own. The delta ships them inside
# the record that owns them, so attaching a specimen type to a test type has to
# move the test type — otherwise the change reaches no local node.
module BumpsOwnerRevision
  extend ActiveSupport::Concern

  included do
    class_attribute :revision_owners, instance_writer: false, default: []

    after_create :bump_owner_revisions
    after_update :bump_owner_revisions
    after_destroy :bump_owner_revisions
  end

  class_methods do
    def bumps_revision_of(*names)
      self.revision_owners = names
    end
  end

  private

  def bump_owner_revisions
    revision_owners.each do |name|
      owner = public_send(name)
      # Nothing to tell anyone about when the owner is going away too.
      next if owner.nil? || owner.destroyed? || owner.frozen?

      owner.touch_revision!
    end
  end
end
