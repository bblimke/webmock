require "spec_helper"

# Borrowed from Bundler
# https://github.com/carlhuda/bundler/blob/1-0-stable/spec/quality_spec.rb
describe "The library itself" do
  def check_for_tab_characters(filename)
    failing_lines = []
    File.readlines(filename).each_with_index do |line,number|
      failing_lines << number + 1 if line =~ /\t/
    end

    unless failing_lines.empty?
      "#{filename} has tab characters on lines #{failing_lines.join(', ')}"
    end
  end

  def check_for_extra_spaces(filename)
    failing_lines = []
    File.readlines(filename).each_with_index do |line,number|
      next if line =~ /^\s+#.*\s+\n$/
      failing_lines << number + 1 if line =~ /\s+\n$/
    end

    unless failing_lines.empty?
      "#{filename} has spaces on the EOL on lines #{failing_lines.join(', ')}"
    end
  end

  RSpec::Matchers.define :be_well_formed do
    failure_message_for_should do |actual|
      actual.join("\n")
    end

    match do |actual|
      actual.empty?
    end
  end

  it "has no malformed whitespace" do
    error_messages = []
    Dir.chdir(File.expand_path("../..", __FILE__)) do
      `git ls-files`.split("\n").each do |filename|
        next if filename =~ /\.gitmodules|fixtures/
        error_messages << check_for_tab_characters(filename)
        error_messages << check_for_extra_spaces(filename)
      end
    end
    error_messages.compact.should be_well_formed
  end

  it "can still be built" do
    Dir.chdir(File.expand_path('../../', __FILE__)) do
      `gem build webmock.gemspec`
      $?.should be == 0

      # clean up the .gem generated
      system("rm webmock-#{WebMock.version}.gem")
    end
  end
end
