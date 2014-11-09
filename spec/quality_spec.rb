require "spec_helper"

# Borrowed from Bundler
# https://github.com/carlhuda/bundler/blob/1-0-stable/spec/quality_spec.rb
# Portions copyright (c) 2010 Andre Arko
# Portions copyright (c) 2009 Engine Yard

# MIT License

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
    failure_message do |actual|
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
    expect(error_messages.compact).to be_well_formed
  end

  it "can still be built" do
    Dir.chdir(File.expand_path('../../', __FILE__)) do
      `gem build webmock.gemspec`
      expect($?).to eq(0)

      # clean up the .gem generated
      system("rm webmock-#{WebMock.version}.gem")
    end
  end
end
