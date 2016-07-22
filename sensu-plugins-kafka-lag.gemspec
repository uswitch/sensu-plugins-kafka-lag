lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'

require_relative 'lib/sensu-plugins-kafka-lag'

Gem::Specification.new do |s|
  s.authors                = ['Sensu-Plugins and contributors']

  s.date                   = Date.today.to_s
  s.description            = 'This plugin checks a Kafka consumers lag from the
                              latest offset allowing a threshold. Emits warning
                              if the consumer is lagging, but still consuming.
                              Emits critical if consumer has stopped given
                              the criteria set in options.'
  s.email                  = '<sensu-users@googlegroups.com>'
  s.files                  = Dir.glob('{bin,lib}/**/*.rb') + %w(LICENSE README.md CHANGELOG.md)
  s.executables            = Dir.glob('bin/**/*.rb').map { |file| File.basename(file) }
  s.homepage               = 'https://github.com/andrewmcveigh/sensu-plugins-kafka-lag'
  s.license                = 'MIT'
  s.metadata               = { 'maintainer'         => 'sensu-plugin',
                               'development_status' => 'active',
                               'production_status'  => 'unstable - testing recommended',
                               'release_draft'      => 'false',
                               'release_prerelease' => 'false' }
  s.name                   = 'sensu-plugins-kafka-lag'
  s.platform               = Gem::Platform::RUBY
  s.post_install_message = 'You can use the embedded Ruby by setting
                            EMBEDDED_RUBY=true in /etc/default/sensu'
  s.require_paths          = ['lib']
  s.required_ruby_version  = '>= 2.0.0'

  s.summary                = 'Sensu plugin for checking kafka consumer lag'
  s.test_files             = s.files.grep(%r{^(test|spec|features)/})
  s.version                = SensuPluginsRedis::Version::VER_STRING

  s.add_runtime_dependency 'zookeeper'    , '~> 1.4.10'
  s.add_runtime_dependency 'poseidon'     , '~> 0.0.5'
  s.add_runtime_dependency 'json'         , '~> 1.4'
  s.add_runtime_dependency 'sensu-plugin' , '~> 1.3'

  s.add_development_dependency 'bundler'  , '~> 1.7'
end
