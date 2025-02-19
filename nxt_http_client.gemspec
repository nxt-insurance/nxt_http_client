lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "nxt_http_client/version"

Gem::Specification.new do |spec|
  spec.name          = "nxt_http_client"
  spec.version       = NxtHttpClient::VERSION
  spec.authors       = ["Andreas Robecke", "Nils Sommer", "Raphael Kallensee", "Luetfi Demirci"]
  spec.email         = ["a.robecke@getsafe.de"]

  spec.summary       = %q{NxtHttpClient is a simple DSL on top the typhoeus http gem}
  spec.description   = %q{NxtHttpClient allows you to easily create and configure http clients.}
  spec.homepage      = "https://github.com/nxt-insurance/nxt_http_client"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'typhoeus'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'nxt_registry'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'nxt_vcr_harness'
  spec.add_development_dependency 'redis'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'timecop'
end
