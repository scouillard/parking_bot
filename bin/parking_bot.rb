#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'nokogiri'
require 'json'
require 'yaml'
require 'logger'
require 'time'
require 'rufus-scheduler'

require_relative "../lib/plate_registrar"

LOG_PATH = File.expand_path('../log/logs.log', __dir__)
Dir.mkdir(File.dirname(LOG_PATH)) unless Dir.exist?(File.dirname(LOG_PATH))

PLATES_PATH = File.expand_path("../../config/plates.yml", __FILE__)
plates = YAML.load_file(PLATES_PATH)

DATES_PATH = File.expand_path("../../config/dates.yml", __FILE__)
dates = YAML.load_file(DATES_PATH)

scheduler = Rufus::Scheduler.new(tz: "America/New_York")

puts "Lauching CarletonU Parking Bot..."

dates.each do |ts|
  scheduler.at Time.parse(ts) do
    registrar = PlateRegistrar.new(plates)
    registrar.register_all_plates
  end
end

scheduler.join