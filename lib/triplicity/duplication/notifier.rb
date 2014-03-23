#
# notifier.rb - statefully manages all notifications of a duplication destination
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

module Triplicity
  module Duplication
    class Notifier
      def initialize(notifications)
        @notifications = notifications
      end

      def begin_copying
        progressing_notification do |notification|
          notification.summary = "Beginning to copy a plan's backup"
          notification.body = "Copying source to #{destination_human_name}"
        end
      end

      def end_copying_successfully
        progressing_notification(success: true) do |notification|
          notification.summary = "Finished copying a plan's backup"
          notification.body = "Copied source to #{destination_human_name}"
        end
      end

      def remind
        progressing_notification do |notification|
          notification.summary = 'Please connect your secondary backup location'
          notification.body = reminder_message
        end
      end

      # @TODO think this reason thing over
      def copying_failed(reason)
        progressing_notification(failure: true) do |notification|
          notification.summary = "Failed copying a plan's backup"
          notification.body = "Reason: #{reason}"
        end # unless error.is_a?(Destination::Base::NotifiedOperationError)
      end

      def destination_human_name
        'destination'
      end

      def reminder_message
        "Destination #{destination_human_name} latest backup is of NYI"
      end

      private

      def progressing_notification(options = {})
        notification = if @notification
          @notification.issue { |n| yield n }
        else
          @notifications.issue { |n| yield n }
        end

        if options[:success]
          if @error_notification
            @error_notification.close
            @error_notification = nil
          end
          @notification = notification
        elsif options[:failure]
          @error_notification = notification
          @notification = nil
        end
      end
    end
  end
end
