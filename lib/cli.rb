require_relative "env"

# Helpers shared by bin/dates, bin/plates, bin/discount and bin/status.
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
  # Where the service isn't installed (e.g. a laptop), the change only touched
  # local copies: say so, since the server's files are the ones that count.
  def restart_bot
    unless system("systemctl", "is-enabled", "--quiet", SERVICE, err: File::NULL)
      warn "\e[33mThe bot isn't installed here, so this only changed this machine's copy. " \
           "To change the server's, run it as bin/remote #{File.basename($PROGRAM_NAME)} ...\e[0m"
      return
    end

    if system("systemctl", "restart", SERVICE)
      ok "Restarted #{SERVICE}."
    else
      fail! "Could not restart #{SERVICE}: run `systemctl status #{SERVICE}`."
    end
  end
end
