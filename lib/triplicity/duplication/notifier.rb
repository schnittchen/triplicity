# coding: utf-8

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

      attr_accessor :backup_name
      attr_writer :location_name

      def begin_copying
        progressing_notification do |notification|
          notification.summary = "Beginning to copy #{backups_phrase}"
          notification.body = "Copying backups to #{location_name}"
        end
      end

      def end_copying_successfully
        progressing_notification(success: true) do |notification|
          notification.summary = "Finished copying #{backups_phrase}"
          notification.body = "Copied backups to #{location_name}"
        end
      end

      def remind
        progressing_notification do |notification|
          notification.summary = "Please connect secondary backup location «#{location_name}»"
          notification.body = reminder_message
        end
      end

      # @TODO think this reason thing over
      def copying_failed(reason)
        progressing_notification(failure: true) do |notification|
          notification.summary = "Failed copying #{backups_phrase} to #{location_name}"
          notification.body = "Reason: #{reason}"
        end # unless error.is_a?(Destination::Base::NotifiedOperationError)
      end

      def location_name
        @location_name || 'secondary backup location'
      end

      def reminder_message
        "Latest #{backup_phrase} there is #{latest_destination_backup_time_phrase}"
      end

      private

      def latest_destination_backup_time_phrase
        "of NYI" # @TODO
        # "unknown" / "of #{nicely_formatted_timestamp}"
      end

      def backup_phrase
        backup_name.single_backup_phrase
      end

      def backups_phrase
        backup_name.backups_phrase
      end

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
