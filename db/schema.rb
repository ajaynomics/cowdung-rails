# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_09_185239) do
  create_table "audio_chunks", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data", null: false
    t.integer "sequence", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "format"
    t.integer "sample_rate"
    t.index ["session_id", "sequence"], name: "index_audio_chunks_on_session_id_and_sequence", unique: true
  end

  create_table "bullshit_analyses", force: :cascade do |t|
    t.string "session_id"
    t.boolean "detected"
    t.float "confidence"
    t.string "bs_type"
    t.text "explanation"
    t.text "quote"
    t.text "analyzed_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_duplicate", default: false, null: false
    t.index ["is_duplicate"], name: "index_bullshit_analyses_on_is_duplicate"
    t.index ["session_id"], name: "index_bullshit_analyses_on_session_id"
  end

  create_table "session_transcripts", force: :cascade do |t|
    t.string "session_id"
    t.text "current_text"
    t.text "segments_data"
    t.integer "last_quality_pass_sequence"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "last_processed_text"
    t.index ["session_id"], name: "index_session_transcripts_on_session_id"
  end

  create_table "transcription_segments", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "text", null: false
    t.integer "start_sequence", null: false
    t.integer "end_sequence", null: false
    t.float "duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id", "start_sequence"], name: "index_transcription_segments_on_session_id_and_start_sequence"
    t.index ["session_id"], name: "index_transcription_segments_on_session_id"
  end

  create_table "transcription_sessions", force: :cascade do |t|
    t.string "session_id"
    t.text "last_processed_text"
    t.text "processed_sequences"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_transcription_sessions_on_session_id"
  end
end
