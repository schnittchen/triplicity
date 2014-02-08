require 'thread'

require 'triplicity/destination/factory'

module Triplicity
  class DuplicationPlan
    def initialize(options, primary, application)
      # (save plan's own options here)

      @primary = primary
      @application = application

      @mutex = Mutex.new

      @destination_notifications = {}
      @destination_states = Hash.new { |hash, ident| hash[ident] = {} }

      factory = Destination::Factory.new(primary, application)
      @destinations = extract_destination_options(options).map do |destination_options|
        factory.produce_for_options(destination_options) do |subscription|
          subscribe_on_destination(subscription)
        end
      end

      @primary.on_change do
        propagate_primary_timestamp_to_destinations
      end
      propagate_primary_timestamp_to_destinations

      schedule_reminders # needed as soon as first_unsuccessful_attempt_time is persistent
    end

    private

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

    def schedule_reminders
      messages = []

      mtx do
        helper = NotificationHelper.new

        @destination_states.each_pair do |ident, hash|
          next if hash[:reminders_suspended]

          helper.for_time_data(*hash.values_at(:first_unsuccessful_attempt_time, :last_notification_time))

          next unless helper.notification_due?

          messages << helper.message
          hash[:last_notification_time] = helper.reference
        end
      end

      messages.each do |message|
        @application.notifications.issue do |notification|
          notification.subject = 'Please connect your secondary backup location'
          notification.body = message
        end
      end
    end

    def subscribe_on_destination(subscription)
      ident = subscription.cache_ident

      subscription.on_beginning_connection do |destination|
        mtx { @destination_states[ident][:reminders_suspended] = true }
      end

      subscription.on_successful_connection do |destination|
        issue_begin_copy_notification(destination)
      end

      subscription.on_unsuccessful_connection do |destination|
        mtx do
          # destination has decided copying is needed, but could not connect
          @destination_states[ident][:first_unsuccessful_attempt_time] ||= Time.now
          # @TODO save this in persistent storage instead
        end
        schedule_reminders
      end

      subscription.on_successful_operation do |destination|
        mtx do
          @destination_states[ident].delete :first_unsuccessful_attempt_time
          @destination_states[ident].delete :last_notification_time
        end
        issue_end_copy_notification(destination)
      end

      subscription.on_unsuccessful_operation do |destination, error|
        # @FIXME error will be [Un]NotifiedOperationError
        # we assume the user has already notified appropriately. @FiXME this may totally not be true
        mtx do
          @destination_states[ident][:first_unsuccessful_attempt_time] ||= Time.now
          # @TODO save this in persistent storage instead
        end
      end

      subscription.on_ended_connection do |destination|
        mtx {
          @destination_states[ident][:reminders_suspended] = false
        }
      end
    end

    def extract_destination_options(options)
      options[:destinations]
    end

    def issue_begin_copy_notification(destination)
      notification = @application.notifications.issue do |n|
        n.summary = "Beginning to copy a plan's backup"
        n.body = "Copying source to #{destination.human_name}"
      end

      @destination_notifications[destination.cache_ident] = notification
    end

    def issue_end_copy_notification(destination)
      @destination_notifications[destination.cache_ident].issue do |notification|
        notification.summary = "Finished copying a plan's backup"
        notification.body = "Copied source to #{destination.human_name}"
      end
    end

    def mtx
      @mutex.synchronize(&Proc.new)
    end
  end
end
