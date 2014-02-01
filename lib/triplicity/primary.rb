module Triplicity
  class Primary
    attr_reader :name

    def initialize(path, name)
      @path, @name = path, name
      @subscribers = []
    end

    def site
      @site ||= Site.from_path(@path)
    end

    def subscribe_for_changes(&block)
      @subscribers << block
    end

    def site_changed!
      @site = nil
      @subscribers.each(&:call)
    end
  end
end
