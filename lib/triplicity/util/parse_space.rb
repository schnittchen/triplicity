#
# parse_space.rb - interpret a string as an amount of disk space
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

module Triplicity
  module ParseSpace
    private

    def parse_space(value)
      return Float(value) if value.is_a?(Numeric)

      match = /^([\d.]+)([kKmMgGtT]?)[bB]?$/.match(value)

      raise 'bad format' unless match
      num = Float(match[1])
      exp_factor = {
        ''  => 1,
        'k' => 1024,
        'm' => 1024**2,
        'g' => 1024**3,
        't' => 1024**4,
      }.fetch(match[2].downcase)

      num * exp_factor
    end
  end
end
