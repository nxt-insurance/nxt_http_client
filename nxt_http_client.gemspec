
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "nxt_http_client/version"

Gem::Specification.new do |spec|
  spec.name          = "nxt_http_client"
  spec.version       = NxtHttpClient::VERSION
  spec.authors       = ["Andreas Robecke", "Nils Sommer", "Raphael Kallensee", "Luetfi Demirci"]
  spec.email         = ["a.robecke@getsafe.de"]

  spec.summary       = %q{NxtHttpClinet is a simple DSL on top the typhoeus http gem}
  spec.description   = %q{NxtHttpClinet allows you to easily create and configure http clients.}
  spec.homepage      = "https://github.com/nxt-insurance"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = 'https://rubygems.org'

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/nxt-insurance/nxt_http_client"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'typhoeus'
  spec.add_dependency 'activesupport', '~> 5.2'
  spec.add_dependency 'config_x'

  spec.add_development_dependency 'bundler', '~> 1.17'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'vcr'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'nxt_vcr_harness'
  spec.add_development_dependency 'redis'
end
