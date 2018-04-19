# kkt.rb - 'kotsukotsuto' - dollar cost averaging bot
PROGRAM_VERSION = 'ver.20180419_1012'.freeze
PROGRAM_NAME = 'kkt'.freeze

# standerd library require
require 'yaml'
require 'date'

# relateve file
require_relative 'kkt_logger.rb'

# read setting.yaml filr
SETTING = YAML.load_file('setting.yaml')

# global log class
LOG = KktLog.new(SETTING['log']['filepath'])
LOG.enable = SETTING['log']['enable']

# write info of program start.
LOG.info(object_id, 'main', 'main', (PROGRAM_NAME + ' ' + PROGRAM_VERSION))

def alreadybuy(current_unixtime, interval)
  lastbuy = YAML.load_file('lastbuy.yaml')
  return false if lastbuy.nil?
  return false if lastbuy['unixtime'].nil?
  lastbuy_datetime = lastbuy['unixtime'].to_i.div(interval)
  current_unixtime = current_unixtime.div(interval)
  (lastbuy_datetime == current_unixtime) # return true/false
end

def buy
  lastbuytime = Time.now
  puts lastbuytime
  lastbuy = {}
  lastbuy['unixtime'] = lastbuytime.to_i
  lastbuy['coinname'] = 'xrp'
  lastbuy['amout'] = 1
  lastbuy['price'] = 100
  File.open('lastbuy.yaml', 'w') do |f|
    YAML.dump(lastbuy, f)
  end
  LOG.debug(object_id, self.class.name, __method__, '買ったふり')
end

loop do
  current_unixtime = Time.now.to_i
  buy unless alreadybuy(current_unixtime, SETTING['interval'])
  sleep(0.5)
end
