require "minitest/autorun"
require "shellwords"

class DeploymentTest < Minitest::Test
  def test_final_image_disables_multipath_tcp_for_thruster
    stages = {}
    environment = {}
    dockerfile = File.read(File.expand_path("../Dockerfile", __dir__))

    dockerfile.gsub(/\\\n/, " ").each_line do |line|
      instruction, arguments = line.strip.split(/\s+/, 2)

      case instruction
      when "FROM"
        image, _, stage = arguments.split
        environment = stages.fetch(image, {}).dup
        stages[stage] = environment if stage
      when "ENV"
        environment.merge!(Shellwords.split(arguments).map { |entry| entry.split("=", 2) }.to_h)
      end
    end

    settings = environment.fetch("GODEBUG", "").split(",").map { |entry| entry.split("=", 2) }.to_h
    assert_equal "0", settings["multipathtcp"]
  end
end
