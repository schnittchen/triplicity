require 'thread'

require 'triplicity/destination/factory'

module Triplicity
  class DuplicationPlan
    def initialize(options, primary, application)
      # (save plan's own options here)

      @primary = primary
      @application = application

      @mutex = Mutex.new

      factory = Destination::Factory.new(primary, application)

      @destination_handles = extract_destination_options(options).map do |destination_options|
        handle = DestinationHandle.new(self, @application, @mutex)
        handle.destination = factory.produce_for_options(destination_options) do |subscription|
          subscribe_on_destination(subscription, handle)
        end

        handle.issue_reminder
        handle
      end

      @primary.on_change do
        propagate_primary_timestamp_to_destinations
      end
      propagate_primary_timestamp_to_destinations
    end

    private

    class DestinationHandle
      def initialize(plan, application, mutex)
        @plan, @application, @mutex = plan, application, mutex
      end

      attr_accessor :destination

      def cache_ident
        destination.cache_ident
      end

      def new_primary_timestamp(timestamp)
        destination.up_to_dateness.primary_timestamp_changed timestamp
      end

      def suspend_notifications
        @mutex.synchronize { @reminders_suspended = true }
      end

      def resume_notifications
        @mutex.synchronize { @reminders_suspended = false }
        issue_reminder
      end

      def notifications_suspended?
        @reminders_suspended
      end

      def attempt_failed
        now = Time.now
        @mutex.synchronize {
          # save this in cache instead?
          @earliest_failure_time ||= now
        }
      end

      def notify_success
        @mutex.synchronize do
          @earliest_failure_time = nil
          @last_notification_time = nil
        end
      end

      def notify_error(error)
        ## NYI
        # unless error.is_a?(Destination::Base::NotifiedOperationError)
      end

      def issue_reminder
        message = @mutex.synchronize do
          next if notifications_suspended?

          reference = Time.now
          next unless notification_due?(reference)
          @last_notification_time = reference
          reminder_message(reference)
        end

        application.notifications.issue do |notification|
          notification.summary = 'Please connect your secondary backup location'
          notification.body = message
        end if message
      end

      def issue_begin_copy_notification
        @copy_notification = application.notifications.issue do |n|
          n.summary = "Beginning to copy a plan's backup"
          n.body = "Copying source to #{destination.human_name}"
        end
      end

      def issue_end_copy_notification
        @copy_notification.issue do |notification|
          notification.summary = "Finished copying a plan's backup"
          notification.body = "Copied source to #{destination.human_name}"
        end
      end

      private

      attr_reader :plan, :application

      def notification_due?(reference)
        @earliest_failure_time && # was there a failed attempt so far?
          reference - @earliest_failure_time >= 17 && # long enough ago?
          last_notification_long_ago?(reference)
      end

      def last_notification_long_ago?(reference)
        !@last_notification_time || reference - @last_notification_time > 8
      end

      def reminder_message(reference)
        # @TODO @earliest_failure_time is misleading
        "Bad Backup Karma since #{reference - @earliest_failure_time} seconds"
      end
    end

    def propagate_primary_timestamp_to_destinations
      timestamp = @primary.site.latest_timestamp
      @destination_handles.each do |handle|
        handle.new_primary_timestamp(timestamp)
      end
    end

    def subscribe_on_destination(subscription, handle)
      subscription.on_beginning_connection do |destination|
        handle.suspend_notifications
      end

      subscription.on_successful_connection do |destination|
        handle.issue_begin_copy_notification
      end

      subscription.on_unsuccessful_connection do |destination|
        handle.attempt_failed
      end

      subscription.on_successful_operation do |destination|
        handle.notify_success
        handle.issue_end_copy_notification
      end

      subscription.on_unsuccessful_operation do |destination, error|
        handle.attempt_failed
        handle.notify_error(error)
      end

      subscription.on_ended_connection do |destination|
        handle.resume_notifications
      end
    end

    def extract_destination_options(options)
      options[:destinations]
    end
  end
end
