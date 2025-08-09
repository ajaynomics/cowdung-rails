class UpdateBullshitTypesInBullshitAnalyses < ActiveRecord::Migration[8.0]
  def up
    # Update existing types to new categories
    execute <<-SQL
      UPDATE bullshit_analyses#{' '}
      SET bs_type = CASE#{' '}
        WHEN bs_type IN ('jargon', 'buzzwords', 'vague') THEN 'misinformation'
        WHEN bs_type = 'exaggeration' THEN 'impossible'
        WHEN bs_type = 'evasion' THEN 'lie'
        ELSE bs_type
      END
      WHERE bs_type IN ('jargon', 'buzzwords', 'vague', 'exaggeration', 'evasion')
    SQL
  end

  def down
    # Optionally reverse the changes
  end
end
