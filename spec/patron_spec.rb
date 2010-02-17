require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'


unless RUBY_PLATFORM =~ /java/
  require 'patron'
  require 'patron_spec_helper'
  require 'tmpdir'
  require 'fileutils'

  describe "Webmock with Patron" do
    include PatronSpecHelper

    it_should_behave_like "WebMock"

    describe "when custom functionality is used" do
      before(:each) do
        @sess = Patron::Session.new
        @sess.base_url = "http://www.example.com"
      end

      describe "file requests" do

        before(:each) do
          @dir_path = Dir.tmpdir
          @file_path = File.join(@dir_path, "webmock_temp_test_file")
          FileUtils.rm_rf(@file_path) if File.exists?(@file_path)
        end

        after(:each) do
          FileUtils.rm_rf(@dir_path) if File.exist?(@dir_path)
        end


        it "should work with get_file" do         
          stub_http_request(:get, "www.example.com").to_return(:body => "abc")
          @sess.get_file("/", @file_path)
          File.read(@file_path).should == "abc"
        end

        it "should work with put_file" do
          File.open(@file_path, "w") {|f| f.write "abc"}
          stub_http_request(:put, "www.example.com").with(:body => "abc")
          @sess.put_file("/", @file_path)
        end

        it "whould work with post_file" do
          File.open(@file_path, "w") {|f| f.write "abc"}
          stub_http_request(:post, "www.example.com").with(:body => "abc")
          @sess.post_file("/", @file_path)
        end

      end

      it "should work with WebDAV copy request" do
        stub_http_request(:copy, "www.example.com/abc").with(:headers => {'Destination' => "/def"})
        @sess.copy("/abc", "/def")
      end
    end
  end
end
