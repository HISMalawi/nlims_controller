# frozen_string_literal: true

# Sync failures are logged here for manual review and reprocessing if necessary. This model can be expanded in the future to include more details about the failure, such as error messages, timestamps, and retry counts.
class MlabSyncFailure < ApplicationRecord
end
