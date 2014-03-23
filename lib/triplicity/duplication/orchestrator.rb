#
# orchestrator.rb - schedule duplication, retries and notifications for duplication
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/looping_thread'
require 'triplicity/sync_action'

module Triplicity
  module Duplication
    class Orchestrator
      # @TODO remove this relict
      NotifiedOperationError = UnnotifiedOperationError = Class.new(RuntimeError)

      def initialize(application, primary, destination, up_to_dateness, notifier)
        @application = application
        @primary, @destination, @notifier = primary, destination, notifier
        @up_to_dateness = up_to_dateness
        @state = State.new(@up_to_dateness)
      end

      class State
        attr_accessor :failed_since, :last_notification_at, :retry_trigger, :reminder_trigger

        def initialize(up_to_dateness)
          @up_to_dateness = up_to_dateness
        end

        def up_to_date?
          @up_to_dateness.given?
        end

        def retry_pending?
          !!retry_trigger
        end

        def failed?
          !!failed_since
        end

        def reminder_due?(time_reference = Time.now)
          failed? &&
            time_reference - failed_since >= 17 && # long enough ago?
            last_notification_long_ago?(time_reference)
        end

        def last_notification_long_ago?(time_reference)
          !@last_notification_at || time_reference - last_notification_at > 8
        end
      end

      def activate
        @thread = LoopingThread.performing do
          if copying_due?
            attemt_to_copy
          elsif @state.reminder_due?
            issue_reminder
          end
        end.whenever do
          copying_due? or @state.reminder_due?
        end

        @up_to_dateness.when_lost { work_is_possibly_due! }

        @primary.on_change do
          timestamp = @primary.site.latest_timestamp
          @up_to_dateness.primary_timestamp_changed timestamp
        end
      end

      def work_is_possibly_due!
        if copying_due?(ignore_pending_retry: true)
          unschedule_retry
          @thread.poke!
        end
      end

      private

      def copying_due?(options = {}) # @TODO move to State
        !@state.up_to_date? &&
          (options[:ignore_pending_retry] || !@state.retry_pending?)
      end

      def attemt_to_copy
        performed = false
        error = false

        @destination.with_accessible_site do |site|
          @notifier.begin_copying

          action = SyncAction.new(@primary.site, site, @max_space)
          begin
            perform_action_with_timestamp_housekeeping(action)
          rescue NotifiedOperationError, UnnotifiedOperationError => e
            error = e
          else
            performed = true
          end
        end

        if performed
          @state.failed_since = nil
          @state.last_notification_at = nil
          unschedule_retry
          unschedule_reminder
          @notifier.end_copying_successfully
        elsif error
          time = Time.now
          # save this in cache instead?
          @state.failed_since ||= time
          reason = "some reason"
          @notifier.copying_failed(reason)
          @state.last_notification_at = time
          schedule_reminder
          schedule_retry
        else
          @state.failed_since ||= Time.now
          schedule_reminder(unless_pending: true)
          schedule_retry
        end
      end

      def perform_action_with_timestamp_housekeeping(action)
        normalize_action_exceptions do
          action.perform
        end
      ensure
        timestamp = action.latest_target_timestamp
        @up_to_dateness.update_destination_timestamp(timestamp)
      end

      def normalize_action_exceptions
        yield
      rescue NotifiedOperationError, UnnotifiedOperationError
        raise
      rescue => e
        raise UnnotifiedOperationError, e.message
      end

      def schedule_reminder(options = {})
        old_trigger =  @state.reminder_trigger
        return if options[:unless_pending] && old_trigger

        old_trigger.unschedule if old_trigger

        @state.reminder_trigger = @application.reactor.schedule_in(60) do # @TODO time constant
          issue_reminder
          schedule_reminder
        end
      end

      def unschedule_reminder
        if trigger = @state.reminder_trigger
          @state.reminder_trigger = nil
          trigger.unschedule
        end
      end

      def issue_reminder
        @notifier.remind
        @state.last_notification_at = Time.now
      end

      def schedule_retry
        @state.retry_trigger = @application.reactor.schedule_in(1800) do # @TODO time constant
          work_is_possibly_due!
        end
      end

      def unschedule_retry
        if trigger = @state.retry_trigger
          @state.retry_trigger = nil
          trigger.unschedule
        end
      end
    end
  end
end
