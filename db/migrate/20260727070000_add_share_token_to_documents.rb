class AddShareTokenToDocuments < ActiveRecord::Migration[8.1]
  class MigrationDocument < ApplicationRecord
    self.table_name = "documents"
  end

  def change
    add_column :documents, :share_token, :string

    reversible do |dir|
      dir.up do
        MigrationDocument.reset_column_information
        MigrationDocument.where(share_token: nil).find_each do |document|
          document.update_columns(share_token: SecureRandom.urlsafe_base64(18))
        end
      end
    end

    add_index :documents, :share_token, unique: true
  end
end
