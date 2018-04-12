# kkt.rb - 'kotsukotsuto' - dollar cost averaging bot
PROGRAM_VERSION = 'ver.20180411_0645'.freeze
PROGRAM_NAME = 'kkt'.freeze

# standerd library require
require 'yaml'

# relateve file
require_relative 'kkt_logger.rb'

# read setting.yaml filr
SETTING = YAML.load_file('setting.yaml')

# global log class
LOG = KktLog.new(SETTING['log']['filepath'])
LOG.enable = SETTING['log']['enable']

# write info of prgram start.
LOG.info(object_id, 'main', 'main', (PROGRAM_NAME + ' ' + PROGRAM_VERSION))
