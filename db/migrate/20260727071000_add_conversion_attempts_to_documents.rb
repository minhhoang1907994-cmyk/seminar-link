class AddConversionAttemptsToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :conversion_attempts, :integer, null: false, default: 0
  end
end
