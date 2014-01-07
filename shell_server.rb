#!/usr/bin/env ruby

require 'logger'
require 'redis'
require 'hiredis'

logger = Logger.new('logs/shell_server.log')
logger.info("Starting up shell server")

redis = Redis.new(driver: :hiredis)

redis.psubscribe('*') do |on|
  on.message do |channel, message|
    logger.info(sprintf("[%s]: %s\n", channel, message))
  end
end
