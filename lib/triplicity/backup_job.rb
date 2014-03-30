#
# backup_job.rb - regularly spawns subshell and handles success or failure
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/looping_thread'

require 'time' # for Time.parse

module Triplicity
  class BackupJob

    # this naive implementation assumes the latest timestamp taken from a manifest filename
    # is the time of the last successful backup. maybe that is even the case, if duplicity
    # creates the manifest last and atomically.

    def initialize(application, primary, config)
      @application, @primary = application, primary

      @schedule_seconds = config['seconds']
      @retry_seconds = config['retry_seconds'] || 600

      @startup_delay = 5

      @executions = config['executions']

      @thread = LoopingThread.performing { work }.whenever { work_to_do? }
      schedule_action
    end

    private

    def single_backup_phrase
      @primary.backup_name.single_backup_phrase
    end

    def notice_start
      @notification = @application.notifications.issue do |n|
        n.summary = "Beginning backup"
        n.body = "Duplicity is creating #{single_backup_phrase}"
      end
    end

    def notice_failure(process_status)
      @last_fail_time = Time.now
      @notification.issue do |n|
        n.summary = "Backup FAILED"
        n.body = "Duplicity failed creating #{single_backup_phrase}: exited with status #{process_status.exitstatus}"
      end
      @application.reactor.schedule_in(@retry_seconds) { @thread.poke! }
    end

    def notice_success
      @notification.issue do |n|
        n.summary = "Backup succeeded"
        n.body = "Duplicity created #{single_backup_phrase}"
      end
      @primary.site_changed!

      schedule_action
    end

    def work
      notice_start

      @executions.each do |execution|
        process_status = execution.run
        unless process_status.success?
          notice_failure process_status
          return
        end
      end

      notice_success
    end

    def work_to_do?
      if @startup_delay
        sleep @startup_delay
        @startup_delay = nil
      end

      !recently_failed? && backup_due?
    end

    def schedule_action
      timestamp = @primary.site.latest_timestamp
      next_time = if timestamp
        next_time = Time.parse(@primary.site.latest_timestamp) + @schedule_seconds
      else
        Time.now
      end

      @application.reactor.schedule_in(next_time - Time.now) { @thread.poke! }
    end

    def backup_due?
      return true unless timestamp = @primary.site.latest_timestamp
      time = Time.parse(timestamp)
      Time.now - time >= @schedule_seconds
    end

    def recently_failed?
      @last_fail_time && Time.now - @last_fail_time < @retry_seconds
    end
  end
end
