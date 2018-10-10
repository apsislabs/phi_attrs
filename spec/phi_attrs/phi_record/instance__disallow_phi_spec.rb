
RSpec.describe 'instance disallow_phi' do
  file_name = __FILE__
  context 'block', skip: 'Not yet implemented' do
    it 'disables all allowances within the block' do |t|
      patient_john.allow_phi!(file_name, t.full_description)
      expect { patient_john.first_name }.not_to raise_error

      patient_john.disallow_phi do
        expect { patient_john.last_name }.to raise_error(access_error)
      end
    end

    it 'returns permission after the block' do |t|
      patient_john.allow_phi!(file_name, t.full_description)
      expect { patient_john.first_name }.not_to raise_error

      patient_john.disallow_phi do
        expect { patient_john.first_name }.to raise_error(access_error)
      end

      expect { patient_john.first_name }.not_to raise_error
    end
  end
end
