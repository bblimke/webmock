module WebMock
  class RegisteredStubDiffer
    def initialize body
      if body
        FileUtils.mkdir_p stub_directory

        save_attempted_file body

        registered = save_registered_stubs
        registered.each { |r| diff r }

        cleanup registered
      end
    end

    private

    def diff registered
      `#{diff_tool} #{registered} #{attempted_file}`
    end

    def attempted_file
      attempted = File.join stub_directory, "attempted_stub.txt"
    end

    def stub_directory
      File.join %w(tmp webmock)
    end

    def cleanup files
      File.delete attempted, *files
    end

    def save_attempted_file body
      File.open(attempted, "w") { |f| f << body }
    end

    def save_registered_stubs
      WebMock::StubRegistry.instance.request_stubs.map.
        each_with_index do |stub, index|
        file = "tmp/webmock/registered_stub_#{index}"

        File.open file, "w" do |f|
          f << stub.request_pattern.body_pattern
        end

        file
        end
    end

    def diff_tool
      ENV['diff_tool'] || "opendiff"
    end
  end
end
