require 'spec_helper'

describe 'simp::knockout' do
  context 'when passed a mixxed array' do
    let(:array) { ['socrates', 'plato', 'aristotle', '--socrates'] }
    it { is_expected.to run.with_params(array).and_return(['plato', 'aristotle']) }
  end
end
