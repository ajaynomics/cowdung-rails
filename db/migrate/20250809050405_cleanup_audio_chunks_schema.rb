class CleanupAudioChunksSchema < ActiveRecord::Migration[8.0]
  def change
    # Remove unused processed column and its indexes
    remove_index :audio_chunks, [ :session_id, :processed ]
    remove_index :audio_chunks, :session_id
    remove_column :audio_chunks, :processed, :boolean
  end
end
