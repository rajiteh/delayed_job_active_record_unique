# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "delayed_job_active_record_unique"
  spec.version       = "0.0.2"
  spec.authors       = ["Rajitha Perera"]
  spec.email         = ["rajiteh@gmail.com"]
  spec.summary       = %q{Extend DelayedJob to support unique job indentification.}
  spec.description   = %q{This gem extends DelayedJob functionality by providing a simple interface to specify if the job being enqueued needs to
be unique within the queue.}
  spec.homepage      = "http://github.com/rajiteh/delayed_job_active_record_unique"
  spec.license       = "MIT"

  spec.files         = %w(CONTRIBUTING.md LICENSE.md README.md delayed_job_active_record_unique.gemspec) + Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "delayed_job_active_record", [">= 4.0", "< 5.0"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
