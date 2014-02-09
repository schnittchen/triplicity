require 'triplicity/sync_thread'

require 'time' # for Time.parse

module Triplicity
  class BackupJob

    # this naive implementation assumes the latest timestamp taken from a manifest filename
    # is the time of the last successful backup. maybe that is even the case, if duplicity
    # creates the manifest last and atomically.

    def initialize(application, primary, config)
      @application, @primary = application, primary

      @schedule_seconds = config['seconds']
      @retry_seconds = config['retry_seconds'] || 5

      @startup_delay = 5

      prepare_spawn_args(config)

      @thread = SyncThread.performing { work }.whenever { work_to_do? }
    end

    private

    def notice_start
      @notification = @application.notifications.issue do |n|
        n.summary = "Beginning backup"
        n.body = "Backup on #{@primary.instance_variable_get(:@path)}" # @FIXME
      end
    end

    def notice_failure(process_status)
      @last_fail_time = Time.now
      @notification.issue do |n|
        n.summary = "Backup FAILED"
        n.body = "Backup process exited with status #{process_status.exitstatus}"
      end
      @application.reactor.schedule_in(@retry_seconds) { @thread.poke! }
    end

    def notice_success
      @notification.issue do |n|
        n.summary = "Backup succeeded"
      end
      @primary.site_changed!
    end

    def prepare_spawn_args(config)
      command = config['command']
      chdir = config['chdir']
      @spawn_args = [*command]
      @spawn_args << {
        chdir: chdir
      } if chdir
    end

    def work
      notice_start

      system(*@spawn_args)

      if $?.success?
        notice_success
      else
        notice_failure $?
      end
    end

    def work_to_do?
      if @startup_delay
        sleep @startup_delay
        @startup_delay = nil
      end

      !recently_failed? && backup_due?
    end

    def backup_due?
      time = Time.parse(@primary.site.latest_timestamp)
      Time.now - time >= @schedule_seconds
    end

    def recently_failed?
      @last_fail_time && Time.now - @last_fail_time < @retry_seconds
    end
  end
end
