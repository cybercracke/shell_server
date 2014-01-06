
base_directory = File.expand_path(File.dirname(__FILE__))
$:.unshift(base_directory) unless $:.include?(base_directory)

require 'web_server'

run App
