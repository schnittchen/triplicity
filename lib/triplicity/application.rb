require 'triplicity/reactor'

module Triplicity
  class Application
    def initialize
      @reactor = Reactor.new
    end

    def run
      @reactor.pending_work_handler { puts "work handler" }

      ## working example:
      # trap("INT") {
      #   @reactor.schedule { puts "scheduled" }
      #   @reactor.interrupt_sleep
      # }

      @reactor.run
    end
  end
end