class CreateTranscriptionSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :transcription_sessions do |t|
      t.string :session_id
      t.text :last_processed_text
      t.text :processed_sequences

      t.timestamps
    end
    add_index :transcription_sessions, :session_id
  end
end
