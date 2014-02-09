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
