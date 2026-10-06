# frozen_string_literal: true

##
# Worker for pushing orders to NLIMS
# Handles regular push, force sync, and order updates
class PushOrdersWorker
  def run
    return unless Config.local_nlims?

    Rails.logger.info('Starting orders push to NLIMS')

    push_orders
    force_sync_orders
    push_order_updates
    push_added_tests

    Rails.logger.info('Orders push completed successfully')
  rescue StandardError => e
    Rails.logger.error("Error pushing orders: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def push_orders
    Rails.logger.info('Pushing Orders to NLIMS')
    SyncToNlimsService.push_order_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error pushing orders: #{e.message}")
  end

  def force_sync_orders
    Rails.logger.info('Force Pushing Orders to NLIMS')
    SyncToNlimsService.force_sync_order_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error force pushing orders: #{e.message}")
  end

  def push_order_updates
    Rails.logger.info('Pushing Order Updates to NLIMS')
    SyncToNlimsService.push_order_update_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error pushing order updates: #{e.message}")
  end

  def push_added_tests
    Rails.logger.info('Pushing Added Tests to NLIMS')
    SyncToNlimsService.push_added_tests_to_nlims
  rescue StandardError => e
    Rails.logger.error("Error pushing added tests: #{e.message}")
  end
end
