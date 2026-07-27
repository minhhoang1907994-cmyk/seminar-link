class AddFilePasswordToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :file_password_salt, :string
    add_column :documents, :file_password_digest, :string
  end
end
