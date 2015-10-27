require 'spec_helper'
describe 'not_augeas' do

  context 'with defaults for all parameters' do
    it { should contain_class('not_augeas') }
  end
end
