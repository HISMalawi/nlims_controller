# frozen_string_literal: true

# A link waiting for the entry it points at. See the migration for why these
# happen on every first sync.
class DictionaryLinkDeferral < ApplicationRecord
  def self.remember!(owner:, link_name:, target_code:)
    create!(
      owner_entity_type: owner.class.entity_type,
      owner_uuid: owner.uuid,
      link_name: link_name.to_s,
      target_code: target_code,
      created_at: Time.current
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def self.forget_for(owner:, link_name:)
    where(owner_uuid: owner.uuid, link_name: link_name.to_s).delete_all
  end

  def owner
    Dictionary.model_for(owner_entity_type)&.find_by(uuid: owner_uuid)
  end
end
