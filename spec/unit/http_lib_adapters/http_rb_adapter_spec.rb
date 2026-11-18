require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'tmpdir'

describe "WebMock's http_rb adapter" do
  it "should not be loaded when HTTP has a VERSION but no Client" do
    Dir.mktmpdir('webmock-') do |dir|
      File.write(File.join(dir, 'http.rb'), "module HTTP\n  VERSION = '1.0.0'\nend\n")
      lib = File.expand_path('../../../lib', __dir__)
      script = 'require "webmock"; print defined?(WebMock::HttpLibAdapters::HttpRbAdapter).inspect'

      output, errors, status = Open3.capture3(RbConfig.ruby, '-I', dir, '-I', lib, '-e', script)

      expect(status).to be_success, errors
      expect(output).to eq('nil')
    end
  end
end
