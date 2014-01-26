require 'pathname'

require 'triplicity/site/instance'

module Triplicity
  module Site
    def self.from_path(path)
      Instance.new(path)
    end
  end
end
