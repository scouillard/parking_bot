require 'net/http'
require 'uri'
require 'nokogiri'
require 'json'
require 'yaml'

def color_text(text, color_code)
  "\e[#{color_code}m#{text}\e[0m"
end

def send_confirmation_email!(location_url, doc, ref, plate, cookie_header)
  email = PLATES[plate]
  csrf_token = doc.at_css('meta[name="csrfToken"]')&.attr('content')
  unless csrf_token
    log("⚠️ CSRF token not found, skipping email.", 31)
    return
  end

  base_uri = URI.parse(location_url)
  post_uri = URI.join("#{base_uri.scheme}://#{base_uri.host}", '/tapPoster/sendReceipt')

  request = Net::HTTP::Post.new(post_uri)
  request['Content-Type'] = 'application/json'
  request['X-CSRF-Token'] = csrf_token
  request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
  request['Referer'] = location_url
  request['Cookie'] = cookie_header if cookie_header
  request.body = { email: email, nfcTapParkingID: ref.to_i }.to_json

  response = Net::HTTP.start(post_uri.host, post_uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  if response.is_a?(Net::HTTPSuccess)
    log("Confirmation email sent to #{email}.", 32)
  else
    log("Failed to send confirmation email: HTTP #{response.code}", 31)
    log("Response Body: #{response.body}", 90) unless response.body.nil? || response.body.strip.empty?
  end
end

timestamp = Time.now.strftime("%A, %d %B %Y at %I:%M %p")
puts "Starting CarletonU Parking Script for #{timestamp}"

PLATES.keys.each_with_index do |plate, index|
  puts "Processing plate #{index + 1}/#{PLATES.size}..."

  begin
    uri = URI.parse("https://hotspotparking.com/tapPoster/startParkingSession?tapToken=CarletonTemp111&plate=#{plate}&time=3&discount=1000&discountCodeID=769&fee=NaN")

    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPRedirection)
      location = response['location']

      if location.include?('/purchase_success/')
        ref = location.split('/').last
        uri = URI.parse(location)
        response = Net::HTTP.get_response(uri)
        set_cookie = response.get_fields('Set-Cookie')
        cookie_header = set_cookie&.map { |c| c.split(';').first }&.join('; ')
        doc = Nokogiri::HTML(response.body)
        log "Plate #{plate} has been successfully registered. Reference Number: #{ref}. Sending confirmation email...", 32

        send_confirmation_email!(location, doc, ref, plate, cookie_header)
      else
        log "Plate #{plate} failed to redirect to success. Redirected to: #{location}", 31
      end
    end

    sleep(rand(2..5))
  rescue => e
    log "Error processing plate #{plate}: #{e.message}", 31
  end
end