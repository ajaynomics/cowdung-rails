class AddIsDuplicateToBullshitAnalyses < ActiveRecord::Migration[8.0]
  def change
    add_column :bullshit_analyses, :is_duplicate, :boolean, default: false, null: false
    add_index :bullshit_analyses, :is_duplicate
  end
end
