class CreateTranscriptionSegments < ActiveRecord::Migration[8.0]
  def change
    create_table :transcription_segments do |t|
      t.string :session_id, null: false
      t.text :text, null: false
      t.integer :start_sequence, null: false
      t.integer :end_sequence, null: false
      t.float :duration

      t.timestamps
    end

    add_index :transcription_segments, :session_id
    add_index :transcription_segments, [ :session_id, :start_sequence ]
  end
end
