require 'net/http'
require 'uri'
require 'time'
require_relative "env"

# Reads the team's game schedule from the league's public iCal feed (the
# "subscribe to calendar" link on the team's schedule page).
module Schedule
  FEED_URL = "https://web.api.digitalshift.ca/partials/stats/schedule/ical"

  Game = Struct.new(:start, :summary)

  module_function

  def feed_uri
    URI.parse(FEED_URL).tap do |uri|
      uri.query = URI.encode_www_form(
        team_id: Env.fetch!("SCHEDULE_TEAM_ID"),
        client_service_id: Env.fetch!("SCHEDULE_CLIENT_SERVICE_ID")
      )
    end
  end

  def minutes_before
    Integer(Env["PARKING_MINUTES_BEFORE"] || 30)
  end

  # Upcoming games that aren't cancelled. Raises if the feed can't be read,
  # so a broken or empty feed never wipes the dates.
  def upcoming_games
    body = fetch(feed_uri)
    events = body.scan(/BEGIN:VEVENT(.*?)END:VEVENT/m).map(&:first)
    raise "the feed has no games (#{body.bytesize} bytes)" if events.empty?

    events.filter_map do |event|
      next if event[/^STATUS:(\S+)/, 1]&.upcase == "CANCELLED"

      Game.new(parse_start(event), event[/^SUMMARY:(.*)$/, 1].to_s.strip)
    end.select { |game| game.start > Time.now }.sort_by(&:start)
  end

  def fetch(uri)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    raise "the feed answered HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    raise "the feed isn't a calendar" unless response.body.include?("BEGIN:VCALENDAR")

    response.body
  end

  # DTSTART is UTC in this feed ("20261015T013000Z"); anything else is refused
  # rather than guessed.
  def parse_start(event)
    value = event[/^DTSTART:(\d{8}T\d{6}Z)\s*$/, 1] or raise "unsupported DTSTART in: #{event[/^DTSTART.*$/]}"

    Time.strptime(value, "%Y%m%dT%H%M%S%z").localtime
  end
end
