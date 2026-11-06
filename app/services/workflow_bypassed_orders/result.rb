# frozen_string_literal: true

module WorkflowBypassedOrders
  # What a service call answers with: the message, the data and the HTTP status the controller should respond with
  Result = Struct.new(:message, :data, :status, :error, keyword_init: true) do
    def self.success(message, data = {}, status = :ok)
      new(message:, data:, status:, error: false)
    end

    def self.failure(message, status = :unprocessable_content)
      new(message:, data: {}, status:, error: true)
    end
  end
end
