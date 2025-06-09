require_relative "utils"

class PlateRegistrar
  include Utils

  def initialize(plates)
    @plates = plates
  end

  def register_all_plates
    @plates.each_with_index do |entry, index|
      puts "Processing plate #{index + 1}/#{@plates.size}..."

      begin
        register_plate(entry)

        sleep(rand(2..5))
      rescue => e
        log "Error processing plate #{entry["plate"]}: #{e.message}", 31
      end
    end
  end

  private

  def register_plate(entry)
    uri = URI.parse("https://hotspotparking.com/tapPoster/startParkingSession?tapToken=CarletonTemp111&plate=#{entry["plate"]}&time=3&discount=1000&discountCodeID=769&fee=NaN")
    response = send_get_request(uri)

    if response.is_a?(Net::HTTPRedirection)
      redirect_string = response['location']

      if redirect_string.include?('/purchase_success/')
        handle_success(redirect_string, entry)
      else
        handle_error(redirect_string, entry)
      end
    end
  end

  def send_get_request(uri, headers = {})
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    headers.each { |k, v| request[k] = v } unless headers.empty?

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end

  def handle_success(redirect_string, entry)
    ref = extract_reference_number(redirect_string)

    log "Plate #{entry["plate"]} has been successfully registered. Reference Number: #{ref}. Sending confirmation email...", 32

    success_uri = URI.parse(redirect_string)
    response = send_get_request(success_uri)

    doc, cookie_header = handle_cookies(response)

    handle_confirmation_email(redirect_string, doc, ref, entry, cookie_header)
  end

  def handle_cookies(response)
    set_cookie = response.get_fields('Set-Cookie')
    cookie_header = set_cookie&.map { |c| c.split(';').first }&.join('; ')
    doc = Nokogiri::HTML(response.body)

    [doc, cookie_header]
  end

  def parse_csrf_token(doc)
    doc.at_css('meta[name="csrfToken"]')&.attr('content')
  end

  def send_post_request(redirect_string, csrf_token, cookie_header, email, ref)
    base_uri = URI.parse(redirect_string)
    post_uri = URI.join("#{base_uri.scheme}://#{base_uri.host}", '/tapPoster/sendReceipt')

    request = Net::HTTP::Post.new(post_uri)
    request['Content-Type'] = 'application/json'
    request['X-CSRF-Token'] = csrf_token
    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    request['Referer'] = redirect_string
    request['Cookie'] = cookie_header if cookie_header
    request.body = { email: email, nfcTapParkingID: ref.to_i }.to_json

    Net::HTTP.start(post_uri.host, post_uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end

  def handle_confirmation_email(redirect_string, doc, ref, entry, cookie_header)
    email = entry["email"]
    csrf_token = parse_csrf_token(doc)

    unless csrf_token
      log("⚠️ CSRF token not found, skipping email.", 31)

      return
    end

    response = send_post_request(redirect_string, csrf_token, cookie_header, email, ref)

    if response.is_a?(Net::HTTPSuccess)
      log("Confirmation email sent to #{email}.", 32)
    else
      log("Failed to send confirmation email: HTTP #{response.code}", 31)
      log("Response Body: #{response.body}", 90) unless response.body.nil? || response.body.strip.empty?
    end
  end

  def extract_reference_number(location)
    location.split('/').last
  end

  def handle_error(redirect_string, entry)
    log "Plate #{entry["plate"]} failed to redirect to success. Redirected to: #{redirect_string}", 31
  end
end