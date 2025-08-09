class AddFormatToAudioChunks < ActiveRecord::Migration[8.0]
  def change
    add_column :audio_chunks, :format, :string
    add_column :audio_chunks, :sample_rate, :integer
  end
end
