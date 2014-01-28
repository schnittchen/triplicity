require 'etc'
require 'pathname'

module Triplicity
  class State
    SCHEMA_VERSION = 0

    def initialize(basename)
      @basename = basename

      if target_path.exist?
        load
      else
        @data = { schema: SCHEMA_VERSION }
        dump
      end
    end

    def destination_latest_timestamp(destination_ident, new_value = nil)
      get_or_set(destination_data(destination_ident), :latest_timestamp, new_value)
    end

    def destination_latest_notification(destination_ident, new_value = nil)
      get_or_set(destination_data(destination_ident), :latest_notification, new_value)
    end

    private

    def get_or_set(hash, key, value)
      if value
        hash[key] = value
        dump
      else
        hash[key]
      end
    end

    def destination_data(ident)
      destinations = @data[:destinations] ||= {}

      destinations[ident] ||= {}
    end

    def target_path
      @target_path ||= Pathname(Etc.getpwuid.dir) + '.cache' + @basename
    end

    def load
      @data = Marshal.load(target_path.read)
    end

    def dump
      IO.write target_path, Marshal.dump(@data)
    end
  end
end
