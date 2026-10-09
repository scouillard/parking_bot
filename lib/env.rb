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

  # Sets keys in .env, keeping every other line (and the file's 600 mode).
  def write(updates)
    lines = File.exist?(PATH) ? File.readlines(PATH, chomp: true) : []
    updates.each do |key, value|
      index = lines.index { |line| line.split("=", 2).first.strip == key }
      index ? lines[index] = "#{key}=#{value}" : lines << "#{key}=#{value}"
    end
    File.write(PATH, lines.join("\n") + "\n", perm: 0o600)
    @values = nil
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
