class AddLastProcessedTextToSessionTranscripts < ActiveRecord::Migration[8.0]
  def change
    add_column :session_transcripts, :last_processed_text, :text
  end
end
