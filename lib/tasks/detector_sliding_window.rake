namespace :detector do
  desc "Test sliding window chunk processing logic"
  task test_sliding_window: :environment do
    puts "\n=== Testing Sliding Window Logic ==="

    # Simulate chunk sequences
    sequences = (0..25).to_a

    sequences.each do |seq|
      if (seq + 1) % 10 == 0
        start_seq = [ seq - 11, 0 ].max
        total_chunks = seq - start_seq + 1
        context_chunks = [ seq - 9 - start_seq, 0 ].max
        new_chunks = 10

        puts "\nSequence #{seq}:"
        puts "  Process chunks: #{start_seq}-#{seq} (#{total_chunks} total)"
        puts "  Context chunks: #{context_chunks}"
        puts "  New chunks: #{new_chunks}"
        puts "  Chunks: #{(start_seq..seq).to_a.join(', ')}"
      end
    end

    puts "\n=== Summary ==="
    puts "- Every 10 seconds: process 10 new chunks"
    puts "- First batch (0-9): 10 chunks total, 0 context"
    puts "- Later batches: 12 chunks total, 2 context"
    puts "- Context overlap ensures continuity"
  end
end
