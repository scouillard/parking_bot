require 'net/http'
require 'uri'
require 'json'
require_relative "env"

# Finds a discount code's numeric ID on the parking poster's page, which
# embeds the valid codes as `let discountCodes = {"<id>":"<code>", ...};`.
module Discount
  POSTER_URL = "https://hotspotparking.com/tapPoster/park/%s"

  module_function

  # The ID for the code, or nil if the poster page doesn't list it.
  # Raises if the page can't be read.
  def lookup(code)
    codes = codes_on_page
    id, = codes.find { |_, value| value.casecmp?(code) }
    id
  end

  def codes_on_page
    uri = URI.parse(format(POSTER_URL, URI.encode_www_form_component(Env.fetch!("PARKING_TAP_TOKEN"))))
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      http.request(request)
    end
    raise "the poster page answered HTTP #{response.code} (is PARKING_TAP_TOKEN right?)" unless response.is_a?(Net::HTTPSuccess)

    json = response.body[/discountCodes\s*=\s*(\{[^}]*\})/, 1] or raise "the poster page has no discount code list any more"
    JSON.parse(json)
  end
end
