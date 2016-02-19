require 'spec_helper'

module WebMock
  describe VersionChecker do
    it 'prints a warning if the major version is too low' do
      checker = VersionChecker.new('foo', '0.7.3', '1.0.0', '1.1')
      expect(Kernel).to receive(:warn).with("\e[31mYou are using foo 0.7.3. WebMock supports version >= 1.0.0, < 1.2.\e[0m")
      checker.check_version!
    end

    it 'prints a warning if the minor version is too low' do
      checker = VersionChecker.new('foo', '1.0.99', '1.1.3', '1.2')
      expect(Kernel).to receive(:warn).with("\e[31mYou are using foo 1.0.99. WebMock supports version >= 1.1.3, < 1.3.\e[0m")
      checker.check_version!
    end

    it 'prints a warning if the patch version is too low' do
      checker = VersionChecker.new('foo', '1.0.8', '1.0.10', '1.2')
      expect(Kernel).to receive(:warn).with("\e[31mYou are using foo 1.0.8. WebMock supports version >= 1.0.10, < 1.3.\e[0m")
      checker.check_version!
    end

    it 'prints a warning if the patch version is too low and max version is not specified' do
      checker = VersionChecker.new('foo', '1.0.8', '1.0.10')
      expect(Kernel).to receive(:warn).with("\e[31mYou are using foo 1.0.8. WebMock supports version >= 1.0.10.\e[0m")
      checker.check_version!
    end

    it 'prints a warning if the major version is too high' do
      checker = VersionChecker.new('foo', '2.0.0', '1.0.0', '1.1')
      expect(Kernel).to receive(:warn).with(/may not work with this version/)
      checker.check_version!
    end

    it 'prints a warning if the minor version is too high' do
      checker = VersionChecker.new('foo', '1.2.0', '1.0.0', '1.1')
      expect(Kernel).to receive(:warn).with(/may not work with this version/)
      checker.check_version!
    end

    it 'does not raise an error or print a warning when the major version is between the min and max' do
      checker = VersionChecker.new('foo', '2.0.0', '1.0.0', '3.0')
      expect(Kernel).not_to receive(:warn)
      checker.check_version!
    end

    it 'does not raise an error or print a warning when the min_patch is 0.6.5, the max_minor is 0.7 and the version is 0.7.3' do
      checker = VersionChecker.new('foo', '0.7.3', '0.6.5', '0.7')
      expect(Kernel).not_to receive(:warn)
      checker.check_version!
    end

    it 'does not raise an error or print a warning when the min_patch is 0.6.5, the max_minor is not specified and the version is 0.8.3' do
      checker = VersionChecker.new('foo', '0.8.3', '0.6.5')
      expect(Kernel).not_to receive(:warn)
      checker.check_version!
    end

    it "prints warning if version is unsupported" do
      checker = VersionChecker.new('foo', '2.0.0', '1.0.0', '3.0', ['2.0.0'])
      expect(Kernel).to receive(:warn).with(%r{You are using foo 2.0.0. WebMock does not support this version. WebMock supports versions >= 1.0.0, < 3.1, except versions 2.0.0.})
      checker.check_version!
    end
  end
end
