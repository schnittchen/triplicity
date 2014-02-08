require 'thread'

require 'triplicity/destination/factory'

module Triplicity
  class DuplicationPlan
    def initialize(options, primary, application)
      # (save plan's own options here)

      @primary = primary
      @application = application

      @mutex = Mutex.new

      @destination_states = Hash.new { |hash, ident| hash[ident] = {} }

      factory = Destination::Factory.new(primary, application)
      @destinations = extract_destination_options(options).map do |destination_options|
        factory.produce_for_options(destination_options) do |subscription|
          subscribe_on_destination(subscription)
        end
      end

      @destination_handles = @destinations.map do |destination|
        @destination_states[destination.cache_ident]

        DestinationHandle.new(destination).tap do |handle|
          handle.mutex = @mutex
          handle.plan = self
        end.tap(&:issue_reminder)
      end

      @primary.on_change do
        propagate_primary_timestamp_to_destinations
      end
      propagate_primary_timestamp_to_destinations
    end

    attr_reader :destination_states, :application # XXX

    private

    def handle_for_destination(destination)
      @destination_handles.find { |handle| handle.destination.equal? destination }
    end

    def handle_for_ident(ident)
      @destination_handles.find { |handle| handle.destination.cache_ident == ident }
    end

    # earliest_failure_time should be cached
    attributes = [
      :destination,
      # :reminders_suspended, :earliest_failure_time, :last_notification_time
    ]
    DestinationHandle = Struct.new(*attributes) do
      attr_accessor :mutex
      attr_accessor :plan

      def cache_ident
        destination.cache_ident
      end

      def suspend_notifications
        @mutex.synchronize { plan.destination_states[cache_ident][:reminders_suspended] = true }
      end

      def resume_notifications
        @mutex.synchronize { plan.destination_states[cache_ident][:reminders_suspended] = false }
        issue_reminder
      end

      def notifications_suspended?
        plan.destination_states[cache_ident][:reminders_suspended]
      end

      def attempt_failed
        now = Time.now
        @mutex.synchronize {
          # save this in cache instead?
          plan.destination_states[cache_ident][:first_unsuccessful_attempt_time] ||= now
        }
      end

      def notify_success
        @mutex.synchronize do
          plan.destination_states[cache_ident].delete :first_unsuccessful_attempt_time
          plan.destination_states[cache_ident].delete :last_notification_time
        end
        issue_end_copy_notification
      end

      def notify_error(error)
        ## NYI
        # unless error.is_a?(Destination::Base::NotifiedOperationError)
      end

      def issue_reminder
        message = @mutex.synchronize do
          helper = NotificationHelper.new
          hash = plan.destination_states[cache_ident]

          next if notifications_suspended?

          helper.for_time_data(*hash.values_at(:first_unsuccessful_attempt_time, :last_notification_time))

          next unless helper.notification_due?

          hash[:last_notification_time] = helper.reference
          helper.message
        end

        plan.application.notifications.issue do |notification|
          notification.summary = 'Please connect your secondary backup location'
          notification.body = message
        end if message
      end

      def issue_begin_copy_notification
        @copy_notification = plan.application.notifications.issue do |n|
          n.summary = "Beginning to copy a plan's backup"
          n.body = "Copying source to #{destination.human_name}"
        end
      end

      private

      def issue_end_copy_notification
        @copy_notification.issue do |notification|
          notification.summary = "Finished copying a plan's backup"
          notification.body = "Copied source to #{destination.human_name}"
        end
      end
    end

    def propagate_primary_timestamp_to_destinations
      timestamp = @primary.site.latest_timestamp
      @destinations.each do |destination|
        destination.up_to_dateness.primary_timestamp_changed timestamp
      end
    end

    class NotificationHelper
      attr_reader :reference

      def initialize
        @reference = Time.now
      end

      def for_time_data(fuat, lnt)
        @since = fuat
        @lnt = lnt
      end

      def notification_due?
        @since && # was there even an attempt so far?
          @reference - @since >= 17 && # long enough ago?
          last_notification_long_ago?
      end

      def message
        "Bad Backup Karma since #{@reference - @since} seconds"
      end

      private

      def last_notification_long_ago?
        !@lnt || @reference - @lnt > 8
      end
    end

    def subscribe_on_destination(subscription)
      ident = subscription.cache_ident

      subscription.on_beginning_connection do |destination|
        handle_for_destination(destination).suspend_notifications
      end

      subscription.on_successful_connection do |destination|
        handle_for_destination(destination).issue_begin_copy_notification
      end

      subscription.on_unsuccessful_connection do |destination|
        handle_for_destination(destination).attempt_failed
      end

      subscription.on_successful_operation do |destination|
        handle_for_destination(destination).notify_success
      end

      subscription.on_unsuccessful_operation do |destination, error|
        handle = handle_for_destination(destination)
        handle.attempt_failed
        handle.notify_error(error)
      end

      subscription.on_ended_connection do |destination|
        handle_for_destination(destination).resume_notifications
      end
    end

    def extract_destination_options(options)
      options[:destinations]
    end

    def mtx
      @mutex.synchronize(&Proc.new)
    end
  end
end
