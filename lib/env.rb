# Reads KEY=VALUE lines from the gitignored .env at the repo root (see .env.example).
module Env
  PATH = File.expand_path("../.env", __dir__)

  module_function

  def values
    @values ||= read
  end

  def [](key)
    value = values[key]
    value unless value.nil? || value.empty?
  end

  def fetch!(key)
    self[key] || abort("Missing #{key} in #{PATH} (see .env.example).")
  end

  def read
    return {} unless File.exist?(PATH)

    File.readlines(PATH, chomp: true).each_with_object({}) do |line, settings|
      next if line.strip.empty? || line.strip.start_with?("#")

      key, value = line.split("=", 2)
      settings[key.strip] = value.to_s.strip.delete_prefix('"').delete_suffix('"')
    end
  end
end
