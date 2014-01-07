#!/usr/bin/env ruby

require 'logger'
require 'securerandom'

require 'redis'
require 'hiredis'

UUID = SecureRandom.uuid

logger = Logger.new('logs/shell_server.log')
logger.info("Starting up shell server")

redis = Redis.new(driver: :hiredis)

# Add this server instance to redis list, TODO expire these in the future.
redis.sadd('shells:servers', UUID)
redis.publish('shells', JSON.generate({'so' => UUID, 'ty' => 'servers:new', 'da' => ""}))

# Start listening to messages
redis.subscribe('shells') do |on|
  on.message do |channel, message|
    logger.info(sprintf("[%s]: %s\n", channel, message))
  end
end
