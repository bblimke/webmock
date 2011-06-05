RSpec::Matchers.define :fail_with do |message|
  match do
    raise_error(RSpec::Expectations::ExpectationNotMetError, message)
  end
end
