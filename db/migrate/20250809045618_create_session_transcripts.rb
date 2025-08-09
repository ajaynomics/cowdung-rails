class CreateSessionTranscripts < ActiveRecord::Migration[8.0]
  def change
    create_table :session_transcripts do |t|
      t.string :session_id
      t.text :current_text
      t.text :segments_data
      t.integer :last_quality_pass_sequence
      t.string :status

      t.timestamps
    end
    add_index :session_transcripts, :session_id
  end
end
