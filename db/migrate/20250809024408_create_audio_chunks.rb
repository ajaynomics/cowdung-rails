class CreateAudioChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :audio_chunks do |t|
      t.string :session_id, null: false
      t.text :data, null: false
      t.integer :sequence, null: false
      t.boolean :processed, default: false, null: false

      t.timestamps
    end

    add_index :audio_chunks, :session_id
    add_index :audio_chunks, [ :session_id, :sequence ], unique: true
    add_index :audio_chunks, [ :session_id, :processed ]
  end
end
