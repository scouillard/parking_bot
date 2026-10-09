#!/usr/bin/env ruby

require 'yaml'
require 'time'
require 'rufus-scheduler'

require_relative "../lib/env"
require_relative "../lib/plate_registrar"

LOG_PATH = File.expand_path('../log/logs.log', __dir__)
Dir.mkdir(File.dirname(LOG_PATH)) unless Dir.exist?(File.dirname(LOG_PATH))

PLATES_PATH = File.expand_path("../../config/plates.yml", __FILE__)
plates = YAML.load_file(PLATES_PATH)

DATES_PATH = File.expand_path("../../config/dates.yml", __FILE__)
dates = YAML.load_file(DATES_PATH)

PARKING_PATH = File.expand_path("../../config/parking.yml", __FILE__)
parking_config = YAML.load_file(PARKING_PATH).merge(
  "tap_token" => Env.fetch!("PARKING_TAP_TOKEN"),
  "discount_code_id" => Env.fetch!("PARKING_DISCOUNT_CODE_ID")
)

scheduler = Rufus::Scheduler.new(tz: "America/New_York")

puts "Launching CarletonU Parking Bot..."

dates.each do |ts|
  scheduler.at Time.parse(ts) do
    registrar = PlateRegistrar.new(plates, parking_config)
    registrar.register_all_plates
  end
end

scheduler.join