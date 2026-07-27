class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :uploader_name, null: false
      t.string :original_filename, null: false
      t.string :status, null: false, default: "pending"
      t.text :error_message

      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :created_at
  end
end
