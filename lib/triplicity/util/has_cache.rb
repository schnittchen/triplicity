#
# has_cache.rb - provide a lookup key for cacheing
#
# Copyright (C) 2014 Thomas Stratmann <thomas.stratmann@rub.de>
# All rights reserved.
# This is free software with ABSOLUTELY NO WARRANTY.
#
# You can redistribute it and/or modify it under the terms of
# the GNU General Public License version 2.
#

require 'digest'
require 'json'

module Triplicity
  module Util
    module HasCache
      def cache_ident
        @cache_ident ||= Digest::SHA256.digest(cache_ident_data.to_json)
      end

      def cache_ident_data
        raise NotImplementedError
      end
    end
  end
end
