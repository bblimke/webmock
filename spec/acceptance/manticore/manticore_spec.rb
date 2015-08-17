require 'spec_helper'
require 'acceptance/webmock_shared'
require 'acceptance/manticore/manticore_spec_helper'

describe "Manticore" do
  include ManticoreSpecHelper

  include_context "with WebMock", :no_status_message
end
