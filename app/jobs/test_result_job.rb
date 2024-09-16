# frozen_string_literal: true

# # TestResultJob that is used to run a test result after commit to db
class TestResultJob
  include Sidekiq::Job

  def perform(test_result_id, method_name)
    test_result = TestResult.find(test_result_id)
    debugger
    test_result.public_send(method_name) if test_result.respond_to?(method_name)
  end
end
