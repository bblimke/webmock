module FixtureHelper
  PATH = File.expand_path('../../fixtures/', __FILE__)

  def fixture(name)
    File.new(File.join(PATH, name.to_s))
  end
end
