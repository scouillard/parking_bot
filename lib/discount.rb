require 'net/http'
require 'uri'
require 'json'
require_relative "env"

# Finds a discount code's numeric ID on the parking poster's page, which
# embeds the valid codes as `let discountCodes = {"<id>":"<code>", ...};`.
module Discount
  POSTER_URL = "https://hotspotparking.com/tapPoster/park/%s"

  module_function

  # The ID for the code on the poster for this tap token, or nil if that
  # poster doesn't list it. Raises if the page can't be read.
  def lookup(code, token = Env.fetch!("PARKING_TAP_TOKEN"))
    id, = codes_on_page(token).find { |_, value| value.casecmp?(code) }
    id
  end

  # Raises if there's no poster page for this tap token.
  def codes_on_page(token = Env.fetch!("PARKING_TAP_TOKEN"))
    uri = URI.parse(format(POSTER_URL, URI.encode_www_form_component(token)))
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      http.request(request)
    end
    raise "there's no poster page for tap token #{token} (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

    json = response.body[/discountCodes\s*=\s*(\{[^}]*\})/, 1] or raise "there's no parking poster for tap token #{token} (or its page changed)"
    JSON.parse(json)
  end
end
