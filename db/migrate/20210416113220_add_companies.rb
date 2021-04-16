class AddCompanies < ActiveRecord::Migration[6.1]
  def change
    create_table :companies, id: :integer do |t|
      t.string :name, null: false
    end
  end
end
