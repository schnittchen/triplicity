# coding: utf-8

#
# backup_name.rb - produces notification phrases related to a backup primary
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

module Triplicity
  class BackupName
    attr_accessor :configured_name

    def primary_keeps_backups_of_path(path)
      @path = path.to_s
    end

    def single_backup_phrase
      "backup of #{backups_of_phrase}"
    end

    def backups_phrase
      "backups of #{backups_of_phrase}"
    end

    private

    def backups_of_phrase
      if configured_name
        "«#{configured_name}»"
      elsif @path
        @path
      else
        "your backup"
      end
    end
  end
end
