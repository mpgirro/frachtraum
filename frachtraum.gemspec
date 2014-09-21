# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'frachtraum'

Gem::Specification.new do |spec|
  spec.name        = 'frachtraum'
  spec.version     = Frachtraum::VERSION
  spec.date        = '2014-09-21'
  spec.summary     = "ZFS volumes management tool"
  spec.description = "lorem ipsum"
  spec.author      = "Maximilian Irro"
  spec.email       = 'max@disposia.org'
  spec.files       = `git ls-files -z`.split("\x0")
  spec.executables = ['frachtraum']
  spec.homepage    = 'https://github.com/mpgirro/frachtraum'
  spec.license     = 'MIT'
  
  spec.require_paths = ['lib']
   
  spec.required_ruby_version = '>= 1.9.3'  
  
  spec.add_dependency 'thor', '~> 0.19'
  spec.add_dependency 'highline', '~> 1.6'
  spec.add_dependency 'parseconfig', '~> 1.0'
  spec.add_dependency 'rainbow', '~> 2.0'
  spec.add_dependency 'terminal-table', '~> 1.4'

end