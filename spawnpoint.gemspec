# frozen_string_literal: true

require_relative "lib/spawnpoint/version"

Gem::Specification.new do |spec|
  spec.name = "spawnpoint"
  spec.version = Spawnpoint::VERSION
  spec.authors = ["bebekim"]
  spec.summary = "A child-friendly Git mask for learning game programming"
  spec.description = "spwn is a thin wrapper around Git that renames Git " \
                     "commands into friendlier, game-like language for kids " \
                     "learning game programming."
  spec.homepage = "https://github.com/bebekim/spawnpoint"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir.chdir(__dir__) { `git ls-files -z`.split("\x0") }
  spec.bindir = "exe"
  spec.executables = ["spwn"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "source_code_uri" => "https://github.com/bebekim/spawnpoint",
    "rubygems_mfa_required" => "true"
  }
end
