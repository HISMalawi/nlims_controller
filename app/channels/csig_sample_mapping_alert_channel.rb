# frozen_string_literal: true

# CsigSampleMappingAlertChannel class for broadcasting alerts
# on used sample ids
class CsigSampleMappingAlertChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'csig_sample_mapping_alert_channel'
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
