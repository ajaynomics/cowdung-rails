# Suppress SQL logging for AudioChunk model to reduce noise in logs
# This is especially useful for models with frequent operations like audio chunks

if Rails.env.development?
  # Option 1: Custom LogSubscriber that filters AudioChunk queries
  class FilteredSqlLogSubscriber < ActiveRecord::LogSubscriber
    SUPPRESSED_TABLES = [ "audio_chunks" ].freeze

    def sql(event)
      # Skip logging if the SQL involves suppressed tables
      sql_query = event.payload[:sql]
      return if SUPPRESSED_TABLES.any? { |table| sql_query&.include?(table) }

      # Otherwise, delegate to the parent implementation
      super
    end
  end

  # Unsubscribe the default ActiveRecord logger
  ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
    if subscriber.is_a?(ActiveRecord::LogSubscriber)
      # Remove all event subscriptions for this subscriber
      subscriber.public_methods(false).reject { |m| m.to_s == "call" }.each do |event|
        ActiveSupport::Notifications.notifier.listeners_for("#{event}.active_record").each do |listener|
          if listener.instance_variable_get("@delegate") == subscriber
            ActiveSupport::Notifications.unsubscribe(listener)
          end
        end
      end
    end
  end

  # Attach our filtered subscriber
  FilteredSqlLogSubscriber.attach_to :active_record
end

# Alternative Option 2: Wrap specific operations (uncomment to use instead)
# module AudioChunkLogging
#   extend ActiveSupport::Concern
#
#   class_methods do
#     def silence_logs(&block)
#       old_logger = ActiveRecord::Base.logger
#       ActiveRecord::Base.logger = nil
#       yield
#     ensure
#       ActiveRecord::Base.logger = old_logger
#     end
#   end
# end
#
# AudioChunk.include(AudioChunkLogging)
#
# # Usage: AudioChunk.silence_logs { AudioChunk.create(...) }

# Alternative Option 3: Using ActiveSupport::Notifications filter (uncomment to use)
# ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
#   event = ActiveSupport::Notifications::Event.new(*args)
#
#   # Don't log if it's an AudioChunk query
#   unless event.payload[:sql]&.include?("audio_chunks")
#     # Re-emit to the default logger
#     ActiveRecord::Base.logger&.debug("  #{event.payload[:name]} (#{event.duration.round(1)}ms)  #{event.payload[:sql]}")
#   end
# end
