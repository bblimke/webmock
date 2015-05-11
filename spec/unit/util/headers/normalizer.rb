require 'spec_helper'
require "csv"

RSpec.describe WebMock::Util::Headers::Normalizer do
  def cleaned_up_csv_value(value)
    if (value =~ /^\[/) == 0
      value
        .gsub("[", "")
        .gsub("]", "")
        .gsub("'", "")
        .split(",")
        .map { |elem| elem.gsub(/\"/, "").gsub(/\\/, "") }
        .map(&:lstrip)
    else
      value
    end
  end

  File.open("spec/support/header_test_data.txt")
  .each_slice(4)
  .reject {|slice|}
  .each do |slice|
    it "converts the headers to the normalized headers" do
      sanitized_array  = slice.map(&:chomp)
      initial_name     = cleaned_up_csv_value sanitized_array[0]
      initial_value    = cleaned_up_csv_value sanitized_array[1]
      normalized_name  = cleaned_up_csv_value sanitized_array[2]
      normalized_value = cleaned_up_csv_value sanitized_array[3]

      actual_array = described_class.new(initial_name, initial_value).call
      expected_array = [normalized_name, normalized_value]

      expect(actual_array[0]).to eq expected_array[0]

      case actual_array[1]
      when Array
        case expected_array[1]
        when Array
          expect(actual_array[1].map{|x| x.gsub(/nil/, "")}).to match_array expected_array[1]
        when String
          expect(actual_array[1].sort).to eq expected_array[1].split(",").map(&:lstrip).sort
        end
      when String
        expect(actual_array[1].gsub(/\"/, "")).to eq expected_array[1].gsub(/\"/, "")
      end
    end
  end
end
