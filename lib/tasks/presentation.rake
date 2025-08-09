namespace :presentation do
  desc "Open the pitch presentation in browser"
  task open: :environment do
    port = ENV.fetch("PORT", 3000)
    url = "http://localhost:#{port}/pitch"

    puts "Opening presentation at #{url}"

    case RbConfig::CONFIG["host_os"]
    when /darwin/
      system "open #{url}"
    when /linux/
      system "xdg-open #{url}"
    when /mswin|mingw|cygwin/
      system "start #{url}"
    else
      puts "Please open #{url} in your browser"
    end
  end

  desc "Test auto-animate features"
  task test: :environment do
    puts <<~INFO
      Auto-Animate Test Checklist:

      1. Title slide morphs smoothly to Problem slide
         - "Soundcheck" text should shrink and fade
         - Boxes should morph from small gray to large red
      #{'   '}
      2. Solution overview animations
         - Circular elements should transform positions
         - Cards should fade in with stagger effect
      #{'   '}
      3. Technical architecture
         - Step cards should slide in from left
         - Connector lines should grow downward
      #{'   '}
      4. Market opportunity
         - Progress bars should animate from 0 to target width
         - Total market value should scale up
      #{'   '}
      5. Business impact
         - Circular progress rings should draw
         - ROI badge should scale in
      #{'   '}
      Navigate with arrow keys or spacebar.
      Press ESC to see slide overview.
    INFO
  end
end
