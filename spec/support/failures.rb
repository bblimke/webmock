module Failures
  def fail()
  raise_error(RSpec::Expectations::ExpectationNotMetError)
  end

  def fail_with(message)
    raise_error(RSpec::Expectations::ExpectationNotMetError, message)
  end
end
