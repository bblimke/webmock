require 'spec_helper'
require 'acceptance/webmock_shared'

if RUBY_PLATFORM =~ /java/
  require 'acceptance/manticore/manticore_spec_helper'

  describe "Manticore" do
    include ManticoreSpecHelper

    include_context "with WebMock", :no_status_message
  end
end
