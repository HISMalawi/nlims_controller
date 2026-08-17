# frozen_string_literal: true

module Dictionary
  # One kind of relationship a dictionary entry carries. Declared once so the
  # feed, the reader on a local node and the mLab importer all agree on what a
  # test type is made of.
  Link = Struct.new(:name, :target_entity, :join_model_name, :owner_key, :target_key, keyword_init: true) do
    def join_model
      join_model_name.constantize
    end

    def target_model
      Dictionary.model_for!(target_entity)
    end
  end
end
