# frozen_string_literal: true

RSpec.describe 'delegations' do
  file_name = __FILE__

  let(:address) { build(:address) }
  let(:kwargs) { { avoid_phi: 'avoid' } }

  context 'authorized' do
    it 'delegates to default attribute' do |t|
      address.allow_phi(file_name, t.full_description) do
        expect { address.address }.not_to raise_error
      end
    end

    it 'delegates arguments correctly' do |t|
      address.allow_phi(file_name, t.full_description) do
        expect(address.inlined).to eq(address.address)
        expect(address.inlined(avoid_phi: nil)).to eq(address.address)
      end

      # These calls should never touch the PHI field if delegated correctly
      expect { address.inlined(avoid_phi: 'avoid') }.not_to raise_error
      expect { address.inlined(**kwargs) }.not_to raise_error

      expect(address.inlined(avoid_phi: 'avoid')).to eq('avoid')
      expect(address.inlined(**kwargs)).to eq('avoid')
    end
  end

  context 'unauthorized' do
    it 'raises errors with delegated arguments' do
      # These calls should try to try to access phi, and fail
      expect { address.inlined }.to raise_error(access_error)
      expect { address.inlined(avoid_phi: false) }.to raise_error(access_error)
      expect { address.inlined(avoid_phi: nil) }.to raise_error(access_error)
    end
  end
end
