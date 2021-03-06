class OperationJob < ApplicationJob
  queue_as :default

  rescue_from StandardError, with: :operation_raised_error

  before_perform { |job| job.operation_started }

  after_perform { |job| job.operation_completed }

  protected

    def operation
      arguments.first.tap do |operation|
        if operation.nil?
          Rails.logger.warn "Unable to update failed operation for job: #{self.inspect}"
          break
        end

        unless operation.is_a?(Operation)
          raise ArgumentError, "unexpected type for operation: #{operation.inspect}"
        end
      end
    end

    def operation_started
      operation.present? && operation.update_attribute(:job_started_at, Time.now)
    end

    def operation_succeeded(outcome_url=nil)
      operation.present? && operation.update_attribute(:job_outcome_url, outcome_url) if outcome_url.present?
    end

    def operation_failed(report)
      return unless operation.present?
      save_failure(report)
    end

    def operation_raised_error(exception)
      return unless operation.present?
      ExceptionNotifier.notify_exception(exception)
      save_failure(I18n.t("operation.server_error"))
    end

    def operation_completed
      operation.present? && operation.update_attribute(:job_completed_at, Time.now)
    end

  private

    def save_failure(msg)
      attributes = { job_failed_at: Time.now, job_error_report: msg }
      attributes[:job_completed_at] = Time.now unless operation.completed?
      operation.update_attributes(attributes)
    end
end
