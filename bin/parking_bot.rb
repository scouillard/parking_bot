#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'nokogiri'
require 'json'
require 'yaml'
require 'logger'

require_relative "../lib/plate_registrar"

LOG_PATH = File.expand_path('../log/logs.log', __dir__)
Dir.mkdir(File.dirname(LOG_PATH)) unless Dir.exist?(File.dirname(LOG_PATH))

PLATES_PATH = File.expand_path("../../config/plates.yml", __FILE__)
plates = YAML.load_file(PLATES_PATH)

puts "Lauching CarletonU Parking Bot..."

registrar = PlateRegistrar.new(plates)
registrar.register_all_plates

puts "Done"