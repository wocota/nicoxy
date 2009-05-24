#!/usr/bin/env ruby
require './proxy'
require 'yaml'

config = YAML.load open('config.yaml')

nicoxy = Proxy.new(config)
nicoxy.run
