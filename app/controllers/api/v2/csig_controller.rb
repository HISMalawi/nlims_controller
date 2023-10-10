# frozen_string_literal: true

require 'csig/csig_service'
# module Api
module API
  # module V2
  module V2
    # class CsigController
    class CsigController < ApplicationController
      def generate_specimen_tracking_id
        generated_ids = CsigService.generate_sin(params.require(:number_of_ids))
        render json: generated_ids, status: :created
      end
    end
  end
end
