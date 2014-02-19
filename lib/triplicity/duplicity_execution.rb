module Triplicity
  class DuplicityExecution
    def initialize(segments)
      @segments = segments
    end

    def spawn_args
      @segments.map do |segment|
        if segment.respond_to?(:to_duplicity_param)
          String(segment.to_duplicity_param)
        else
          String(segment)
        end
      end
    end

    def run
      system(*spawn_args)
      $?
    end
  end
end
