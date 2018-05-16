class CreatePatientInfos < ActiveRecord::Migration[5.0]
  def change
    create_table :patient_infos do |t|
      t.string :first_name
      t.string :last_name
      t.string :public_id
      t.timestamps
    end
  end
end
