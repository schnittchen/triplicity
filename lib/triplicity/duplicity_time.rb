#
# duplicity_time.rb - point of time in the past for conversion to duplicity TIME FORMAT
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

module Triplicity
  class DuplicityTime
    def self.from_fixnum(fixnum)
      new(fixnum)
    end

    def to_duplicity_param
      # interpret as number of seconds in the past, convert to
      # unix epoch, as string
      (Time.now - @fixnum).to_i.to_s
    end

    def initialize(fixnum)
      @fixnum = fixnum
    end
  end
end
