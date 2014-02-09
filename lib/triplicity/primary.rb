#
# primary.rb - a primary backup location
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'triplicity/site/local'
require 'triplicity/util/on_when'

module Triplicity
  class Primary
    include OnWhen

    on_when.delegates_subscriptions self
    on_when.event :change

    attr_reader :name

    def initialize(path, name)
      @on_when = on_when_new
      @path, @name = path, name
    end

    def site
      @site ||= Site::Local.new(@path)
    end

    def site_changed!
      @site = nil
      on_when.trigger_change
    end
  end
end
