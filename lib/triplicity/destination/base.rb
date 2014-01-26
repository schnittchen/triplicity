require 'digest'
require 'json'

module Triplicity
  module Destination
    class Base
      attr_reader :max_space
      attr_accessor :youngest_timestamp

      def initialize(config = {})
        @max_space = canonicalize_max_space(config['max_space'])
      end

      def canonicalize_max_space(value)
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
end
