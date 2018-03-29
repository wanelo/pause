require 'spec_helper'

describe Pause::Logger do
  before do
    expect(STDOUT).to receive(:puts).with('hello')
    expect(STDERR).to receive(:puts).with('whoops'.red)
  end

  it 'will call through STDOUT/STDERR' do
    described_class.puts('hello')
    described_class.fatal('whoops')
  end
end
