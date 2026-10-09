require 'shellwords'

# Helpers shared by bin/dates and bin/plates.
module CLI
  CONFIG_DIR = File.expand_path("../config", __dir__)
  ENV_PATH = File.expand_path("../.env", __dir__)
  SERVICE = "parking_bot"

  module_function

  # On the laptop, .env names the server (see .env.example): run the same
  # command there over SSH and exit. On the server there is no .env, so the
  # script carries on and edits the config itself.
  def forward_to_server!(script)
    settings = read_env
    host = settings["PARKING_BOT_SSH"]
    return if host.nil? || host.empty?

    dir = settings.fetch("PARKING_BOT_DIR", "parking_bot")
    ssh = ["ssh"]
    ssh += ["-i", File.expand_path(settings["PARKING_BOT_SSH_KEY"])] if settings["PARKING_BOT_SSH_KEY"]
    remote = "cd #{Shellwords.escape(dir)} && bin/#{script} #{ARGV.shelljoin}"
    exec(*ssh, host, remote)
  end

  def read_env
    return {} unless File.exist?(ENV_PATH)

    File.readlines(ENV_PATH, chomp: true).each_with_object({}) do |line, settings|
      next if line.strip.empty? || line.strip.start_with?("#")

      key, value = line.split("=", 2)
      settings[key.strip] = value.to_s.strip.delete_prefix('"').delete_suffix('"')
    end
  end

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
