#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'securerandom'

require 'redis'
require 'hiredis'

UUID = SecureRandom.uuid
SERVER_NAME = SecureRandom.hex(10)
PTYS = {}

module MessageHandler
  def process(raw_message)
    message = JSON.parse(raw_message)

    # Log the message we received
    $logger.info(raw_message)

    # Ignore any message not destined for us
    return if message['de'] != UUID

    case message['ty']
    when 'shell:new'
      shell_id = SecureRandom.hex(4)
      $logger.info("[%s]: Opening new shell %s\n" % [UUID, shell_id])
      Thread.current[:redis].publish('shells', JSON.generate({'so' => UUID, 'de' => message['so'], 'ty' => 'shell:new', 'da' => shell_id}))
    end
  end

  module_function :process
end

$logger = Logger.new('logs/shell_server.log')
$logger.info("Starting up shell server #{UUID} -> #{SERVER_NAME}")

redis_sub = Redis.new(driver: :hiredis)

Thread.current[:redis] = Redis.new(driver: :hiredis)

trap(:INT) { redis_sub.unsubscribe('shells'); exit }

# Start listening to messages
redis_sub.subscribe('shells') do |on|
  on.subscribe do
    # Add this server instance to redis list, TODO expire these in the future.
    Thread.current[:redis].sadd('shells:servers', JSON.generate({'uuid' => UUID, 'name' => SERVER_NAME}))
    Thread.current[:redis].publish('shells', JSON.generate({'so' => UUID, 'ty' => 'servers:new', 'da' => ""}))
  end

  on.message do |_, message|
    MessageHandler.process(message)
  end

  on.unsubscribe do
    Thread.current[:redis].srem('shells:servers', JSON.generate({'uuid' => UUID, 'name' => SERVER_NAME}))
    Thread.current[:redis].publish('shells', JSON.generate({'so' => UUID, 'ty' => 'servers:removed', 'da' => ""}))
  end
end
