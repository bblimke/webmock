require 'spec_helper'

describe WebMock do
  its(:version) { should == WebMock::VERSION }
end
