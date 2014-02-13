#
# fixnum.rb - Extensions on the Fixnum class
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

class Fixnum
  def second
    self
  end
  alias_method :seconds, :second

  def minute
    self * 60
  end
  alias_method :minutes, :minute

  def hour
    self * 60 * 60
  end
  alias_method :hours, :hour

  def day
    self * 60 * 60 * 24
  end
  alias_method :days, :day

  def week
    self * 60 * 60 * 24 * 7
  end
  alias_method :weeks, :week

  def month
    self * 60 * 60 * 24 * 7 * 30
  end
  alias_method :months, :month
end
