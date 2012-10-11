module WebMock
  module Util
    class Util::DateComparator
      def self.compare(date1, date2)
        date1.to_json === date2.to_json
      end
    end
  end
end
