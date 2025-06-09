module Utils
  def log(msg, color_code = 31)
    puts "\e[#{color_code}m#{msg}\e[0m"
    File.open(LOG_PATH, 'a') { |f| f.puts "[#{Time.now}] #{msg}" }
  end
end