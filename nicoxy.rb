#!/usr/bin/env ruby
require './proxy'
require 'yaml'


config = YAML.load( open('config.yaml') )

conf = {
  :port => config['port'] || 8080,
  :cache_folder => config['cache_folder'] || './cache',
  :local_folder => config['local_folder'] || './local',
  :ng_word_file => config['ng_word_file'] || './NGword.txt',
  :flv_wrapper  => config['flv_wrapper'] || false
}

nicoxy = Proxy.new(conf)
