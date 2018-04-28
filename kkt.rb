# kkt.rb - 'kotsukotsuto' - dollar cost averaging bot
PROGRAM_VERSION = 'ver.20180428_1100'.freeze
PROGRAM_NAME = 'kkt'.freeze

# standerd library require
require 'yaml'
require 'date'

# use gem
require 'ruby_bitbankcc'

# relateve file
require_relative 'kkt_logger.rb'

# read setting.yaml filr
SETTING = YAML.load_file('setting.yaml')

# global log class
LOG = KktLog.new(SETTING['log']['filepath'])
LOG.enable = SETTING['log']['enable']

# write info of program start.
LOG.info(object_id, 'main', 'main', (PROGRAM_NAME + ' ' + PROGRAM_VERSION))

BASE_COINNAME = SETTING['base_coin']['coin_name']
TARGET_COINNAME = SETTING['target_coin']['coin_name']

# read coinpair/side from setting file
def coinpair_and_side
  # read setting
  bitbank_coinpair = SETTING['bitbank_coinpair']

  # check pair BASE_TARGET
  pair = BASE_COINNAME + '_' + TARGET_COINNAME
  return [pair, 'sell'] if bitbank_coinpair.include?(pair)

  # check pair TARGET_BASE
  pair = TARGET_COINNAME + '_' + BASE_COINNAME
  return [pair, 'buy'] if bitbank_coinpair.include?(pair)

  # not found
  [nil, nil] # return nil, nil
end

coinpair, side = coinpair_and_side
if coinpair.nil?
  LOG.error(object_id, 'main', 'main', 'no coinpair found. program end.')
  puts('設定ファイルに記述されたコインペアが正しくありません。プログラムを終了しました。')
  exit(-1)
end
LOG.debug(object_id, 'main', 'main', 'coinpair=' + coinpair + ' side=' + side)

# initialize Bitbankcc Class
APIKEY = YAML.load_file('apikey.yaml')
BBCC = Bitbankcc.new(APIKEY['apikey'], APIKEY['seckey'])

def raw_read_balance
  res = JSON.parse(BBCC.read_balance())
  if res['success'] != 1
    errstr = 'BBCC.read_balance() not success. code=' + res['data']['code'].to_s
    LOG.error(object_id, self.class.name, __method__, errstr)
    return nil
  end
  res # return res
rescue => exception
  LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
  nil # return nil
end

def read_amount
  res = raw_read_balance
  ret = Hash.new { |h, k| h[k] = {} }
  res['data']['assets'].each do |one_asset|
    one_asset.each do |key, val|
      ret[one_asset['asset']][key] = val if key != 'asset'
    end
  end
  ret # return ret
end

def free_amout(target_coin)
  read_amount[target_coin]['free_amount']
end

puts(BASE_COINNAME + ' の残高は ' + free_amout(BASE_COINNAME).to_s + ' です。')

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

# loop do
#  current_unixtime = Time.now.to_i
#  buy unless alreadybuy(current_unixtime, SETTING['interval'])
#  sleep(0.5)
# end
