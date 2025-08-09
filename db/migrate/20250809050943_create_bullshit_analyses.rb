class CreateBullshitAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :bullshit_analyses do |t|
      t.string :session_id
      t.boolean :detected
      t.float :confidence
      t.string :bs_type
      t.text :explanation
      t.text :quote
      t.text :analyzed_text

      t.timestamps
    end
    add_index :bullshit_analyses, :session_id
  end
end
