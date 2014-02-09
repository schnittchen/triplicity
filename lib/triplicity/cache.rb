require 'etc'
require 'pathname'

module Triplicity
  class Cache
    SCHEMA_VERSION = 0

    def initialize(basename)
      @basename = basename

      if target_path.exist?
        load
      else
        @data = pristine_data
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
      data = Marshal.load(target_path.read)
      if data[:schema] == SCHEMA_VERSION
        @data = data
      else
        @data = pristine_data
      end
    end

    def pristine_data
      { schema: SCHEMA_VERSION }
    end

    def dump
      IO.write target_path, Marshal.dump(@data)
    end
  end
end
