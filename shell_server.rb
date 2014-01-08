#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'pty'
require 'securerandom'
require 'uri'

require 'redis'
require 'hiredis'

UUID = SecureRandom.uuid
SERVER_NAME = SecureRandom.hex(10)
PTYS = {}
THREADS = []

module MessageHandler
  def process(raw_message)
    message = JSON.parse(raw_message)

    # Ignore any message not destined for us
    return if message['de'] != UUID

    case message['ty']
    when 'shell:new'
      shell_id = SecureRandom.hex(4)
      $logger.info("[%s]: Opening new shell %s\n" % [UUID, shell_id])
      Thread.current[:redis].publish('shells', JSON.generate({'so' => UUID, 'de' => message['so'], 'ty' => 'shell:new', 'da' => shell_id}))

      read_socket, write_socket, pid = PTY.spawn('env PS1="[\u@\h] \w\$ " TERM=xterm-256color COLUMNS=80 LINES=24 sh -i')

      PTYS[shell_id] = {
        read: read_socket,
        write: write_socket,
        pid: pid
      }

      Thread.new(UUID, message['so'], shell_id, PTYS[shell_id]) do |server_id, client_id, shell_id, pty|
        redis = Redis.new(driver: :hiredis)
        logger = Logger.new("logs/shell_#{shell_id}.log")

        begin
          until write_socket.closed?
            chars = pty[:read].readpartial(512)
            logger.info("Read: #{chars}")

            message = {
              'so' => server_id,
              'de' => client_id,
              'ty' => "keys:#{shell_id}",
              'da' => URI.escape(chars)
            }

            redis.publish('shells', JSON.generate(message))
          end
        rescue => e
          logger.error("Shell closed for: #{e.message}")
        end

        message = {
          'so' => server_id,
          'de' => client_id,
          'ty' => 'shells:closed',
          'da' => shell_id
        }

        redis.publish('shells', JSON.generate(message))
      end
    when /^keys:/
      shell_key = message['ty'].split(':').last

      unless PTYS.has_key?(shell_key)
        $logger.warn("Attempted to send keys to invalid shell session")
        return
      end

      # Pass the keys to the PTY:
      PTYS[shell_key][:write].write(URI.unescape(message['da']))
    else
      $logger.info(raw_message)
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
