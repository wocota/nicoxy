#!/usr/bin/env ruby
require './proxy'
require 'yaml'

config = YAML.load( open('config.yaml') )

conf = {
  :port => config['listen_port'] || 8080,
  :cache_folder => config['cache_folder'] || './cache',
  :ng_word_file => config['ng_word_file'] || './NGword.txt'
}

nicoxy = Proxy.new(conf)
