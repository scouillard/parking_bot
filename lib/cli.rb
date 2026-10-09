# Helpers shared by bin/dates and bin/plates.
module CLI
  CONFIG_DIR = File.expand_path("../config", __dir__)
  SERVICE = "parking_bot"

  module_function

  def fail!(msg)
    warn "\e[31m#{msg}\e[0m"
    exit 1
  end

  def ok(msg)
    puts "\e[32m#{msg}\e[0m"
  end

  # The bot reads its config only at startup, so restart it after a change.
  # Skipped where the service isn't installed (e.g. the laptop copy).
  def restart_bot
    unless system("systemctl", "is-enabled", "--quiet", SERVICE, err: File::NULL)
      puts "#{SERVICE} service not installed here: nothing restarted."
      return
    end

    if system("systemctl", "restart", SERVICE)
      ok "Restarted #{SERVICE}."
    else
      fail! "Could not restart #{SERVICE}: run `systemctl status #{SERVICE}`."
    end
  end
end
