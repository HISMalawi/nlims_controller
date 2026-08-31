# frozen_string_literal: true

module Api
  module V3
    # The dictionary feed. Served by both modes and by the same code: a local
    # node pulls from the national one, and a SISLAB or EMR pulls from its local
    # node using exactly this contract. That is what lets the dictionary reach a
    # laboratory whose node is offline from the capital.
    class DictionaryController < Api::BaseController
      MAX_LIMIT = 1000

      def changes
        return unless authorize_scope!("dictionary:read")
        return unless entities

        delta = Dictionary.delta(cursor, entities: entities, limit: limit)

        render_data(
          delta[:entries],
          meta: { cursor: cursor, next_cursor: delta[:next_cursor], has_more: delta[:has_more] }
        )
      end

      # Straight reads for a client that only needs the current catalogue — an
      # EMR building an order form does not want to replay a change feed.
      def index
        return unless authorize_scope!("dictionary:read")

        model = Dictionary.model_for(params[:entity_type])
        return render_api_error(Errors::UNPROCESSABLE, field: "entity_type") if model.nil?

        records = model.active
                       .where(revision: ((cursor + 1)..))
                       .includes(model.delta_includes)
                       .order(:revision, :id)
                       .limit(limit)

        render_data(
          records.map { |record| Dictionary::Serializer.call(model.entity_type, record) },
          meta: { cursor: cursor, next_cursor: records.last&.revision || cursor }
        )
      end

      private

      def cursor
        @cursor ||= params[:since].to_i.clamp(0, Float::INFINITY).to_i
      end

      def limit
        @limit ||= (params[:limit].presence || Dictionary::DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
      end

      # Renders and returns nil on an unknown entity type, so a client that
      # misspells one is told which word was wrong instead of quietly receiving
      # a short feed.
      def entities
        return @entities if defined?(@entities)

        requested = params[:entities].to_s.split(",").map(&:strip).reject(&:empty?)
        @entities = requested.presence || Dictionary::ENTITIES.keys

        unknown = @entities - Dictionary::ENTITIES.keys
        return @entities if unknown.empty?

        render_api_error(Errors::UNPROCESSABLE,
                         message: "entidades desconhecidas: #{unknown.join(', ')}",
                         field: "entities")
        @entities = nil
      end
    end
  end
end
