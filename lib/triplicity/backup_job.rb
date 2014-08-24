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

        exit_code_enum_name = duplicity_exit_code_enum_name(process_status.exitstatus)
        exit_code_string = process_status.exitstatus.to_s
        exit_code_string += " (#{exit_code_enum_name})" if exit_code_enum_name

        n.body = "Duplicity failed creating #{single_backup_phrase}: " \
          "exited with status #{exit_code_string}"
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

    # See http://duplicity.nongnu.org/epydoc/duplicity.log.ErrorCode-class.html
    DUPLICITY_EXIT_CODE_ENUMS = {
      # result is inverted, exit code => string!
      generic: 1,
      command_line: 2,
      hostname_mismatch: 3,
      no_manifests: 4,
      mismatched_manifests: 5,
      unreadable_manifests: 6,
      cant_open_filelist: 7,
      bad_url: 8,
      bad_archive_dir: 9,
      bad_sign_key: 10,
      restore_dir_exists: 11,
      verify_dir_doesnt_exist: 12,
      backup_dir_doesnt_exist: 13,
      file_prefix_error: 14,
      globbing_error: 15,
      redundant_inclusion: 16,
      inc_without_sigs: 17,
      no_sigs: 18,
      restore_dir_not_found: 19,
      no_restore_files: 20,
      mismatched_hash: 21,
      unsigned_volume: 22,
      user_error: 23,
      boto_old_style: 24,
      boto_lib_too_old: 25,
      boto_calling_format: 26,
      ftp_ncftp_missing: 27,
      ftp_ncftp_too_old: 28,
      exception: 30,
      gpg_failed: 31,
      s3_bucket_not_style: 32,
      not_implemented: 33,
      get_freespace_failed: 34,
      not_enough_freespace: 35,
      get_ulimit_failed: 36,
      maxopen_too_low: 37,
      connection_failed: 38,
      restart_file_not_found: 39,
      gio_not_available: 40,
      source_dir_mismatch: 42,
      ftps_lftp_missing: 43,
      volume_wrong_size: 44,
      enryption_mismatch: 45,
      backend_error: 50,
      backend_permission_denied: 51,
      backend_not_found: 52,
      backend_no_space: 53
    }.invert

    def duplicity_exit_code_enum_name(exit_code)
      DUPLICITY_EXIT_CODE_ENUMS.fetch(exit_code)
    end
  end
end
