# kkt.rb - 'kotsukotsuto' - dollar cost averaging bot
PROGRAM_VERSION = 'ver.20180427_2220'.freeze
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

# read coinpair/side from setting file
def coinpair_and_side
  # read setting
  bitbank_coinpair = SETTING['bitbank_coinpair']
  base_coinname = SETTING['base_coin']['coin_name']
  target_coinname = SETTING['target_coin']['coin_name']

  # check pair BASE_TARGET
  pair = base_coinname + '_' + target_coinname
  return [pair, 'sell'] if bitbank_coinpair.include?(pair)

  # check pair TARGET_BASE
  pair = target_coinname + '_' + base_coinname
  return [pair, 'buy'] if bitbank_coinpair.include?(pair)

  # not found
  [nil, nil] # return nil, nil
end

coinpair, side = coinpair_and_side
if coinpair.nil?
  LOG.error(object_id, 'main', 'main', 'no coinpair found.')
  puts('コインペアが見つかりません')
  exit(-1)
end
LOG.debug(object_id, 'main', 'main', 'coinpair=' + coinpair + ' side=' + side)

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
