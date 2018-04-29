# kkt.rb - 'kotsukotsuto' - dollar cost averaging bot
PROGRAM_VERSION = 'ver.20180429_1612'.freeze
PROGRAM_NAME = 'kkt'.freeze

# standerd library require
require 'yaml'
require 'date'

# use gem
require 'ruby_bitbankcc'

# relateve file
require_relative 'kkt_logger.rb'

# read setting.yaml file
SETTING = YAML.load_file('setting.yaml')

# global log class
LOG = KktLog.new(SETTING['log']['filepath'])
LOG.enable = SETTING['log']['enable']

# write info of program start.
LOG.info(object_id, 'main', 'main', (PROGRAM_NAME + ' ' + PROGRAM_VERSION))
puts(PROGRAM_NAME + ' ' + PROGRAM_VERSION)

BASE_COINNAME = SETTING['base_coin']['coin_name']
TARGET_COINNAME = SETTING['target_coin']['coin_name']

RANDOM = Random.new
def random_sleep
  sleep(RANDOM.rand(1.0) + 1)
end

##########
# balance
##########

def api_read_balance
  JSON.parse(BBCC.read_balance)
rescue StandardError => exception
  LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
  nil # return nil
end

def retry_read_balance
  res = nil
  loop do
    res = api_read_balance
    break unless res.nil?
    random_sleep
  end
  res # return res
end

def raw_read_balance
  res = retry_read_balance
  if res['success'] != 1
    errstr = 'BBCC.read_balance() not success. code=' + res['data']['code'].to_s
    LOG.error(object_id, self.class.name, __method__, errstr)
    return nil
  end
  res # return res
end

def read_amount
  ret = Hash.new { |h, k| h[k] = {} }
  res = raw_read_balance
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

########
# price
########

def api_get_price
  JSON.parse(BBCC.read_ticker(COINPAIR))
rescue StandardError => exception
  LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
  nil # return nil
end

def retry_get_price
  res = nil
  loop do
    res = api_get_price
    break unless res.nil?
    random_sleep
  end
  res # return res
end

def price
  ret = {} # empty hash
  res = retry_get_price
  res['data'].each do |key, val|
    ret[key] = val if key != 'success'
  end
  ret # retrun ret
end

def target_price
  return(price['last']) if SIDE == 'buy'
  1 / price['last']
end

########
# order
########

def api_create_order(pair, amount, price, side)
  JSON.parse(BBCC.create_order(pair, amount, price, side, 'market'))
rescue StandardError => exception
  LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
  nil # return nil
end

def retry_create_order(pair, amount, price, side)
  res = nil
  loop do
    res = api_create_order(pair, amount, price, side)
    break unless res.nil?
    random_sleep
  end
  res # return res
end

def raw_create_order(pair, amount, price, side)
  res = retry_create_order(pair, amount, price, side)
  if res['success'] != 1
    errstr = 'BBCC.create_order() not success. code=' + res['data']['code'].to_s
    LOG.error(object_id, self.class.name, __method__, errstr)
    return nil
  end
  res # return res
end

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

# check alread buy
def alreadybuy(current_unixtime, interval)
  lastbuy = YAML.load_file('lastbuy.yaml')
  return false if lastbuy.nil?
  return false if lastbuy['unixtime'].nil?
  lastbuy_datetime = lastbuy['unixtime'].to_i.div(interval)
  current_unixtime = current_unixtime.div(interval)
  (lastbuy_datetime == current_unixtime) # return true/false
rescue StandardError
  false # return false
end

# save last trading info to yaml file
def save_last_trading(target_coinname, amout, price)
  lastbuytime = Time.now
  lastbuy = {}
  lastbuy['unixtime'] = lastbuytime.to_i
  lastbuy['coinname'] = target_coinname
  lastbuy['amout'] = amout
  lastbuy['price'] = price
  File.open('lastbuy.yaml', 'w') do |f|
    YAML.dump(lastbuy, f)
  end
end

# wait for order timing
def wait_loop
  print('wait...')
  loop do
    sleep(0.5)
    redo if alreadybuy(Time.now.to_i, SETTING['interval'])
    puts('go!')
    return
  end
end

COINPAIR, SIDE = coinpair_and_side
if COINPAIR.nil?
  LOG.error(object_id, 'main', 'main', 'no coinpair found. program end.')
  puts('設定ファイルに記述されたコインペアが正しくありません。プログラムを終了しました。')
  exit(-1)
end
LOG.debug(object_id, 'main', 'main', 'setting : coinpair=' +
  COINPAIR + ' side=' + SIDE)

# initialize Bitbankcc Class
APIKEY = YAML.load_file('apikey.yaml')
BBCC = Bitbankcc.new(APIKEY['apikey'], APIKEY['seckey'])

# main loop
loop do
  wait_loop

  # check amout
  tmp_target_price = target_price # api access
  base_free_amount = free_amout(BASE_COINNAME).to_f # api access
  base_use_amount = SETTING['base_coin']['use_amount'].to_f
  base_keep_amount = SETTING['base_coin']['keep_amount'].to_f
  if (base_free_amount - base_keep_amount) < base_use_amount
    tmpstr = Time.now.to_s + ' 残高が足りないので、プログラムを終了します。'
    tmpstr += ' (' + base_free_amount.to_s + ' [' + BASE_COINNAME + '] )'
    LOG.info(object_id, self.class.name, __method__, tmpstr)
    puts(tmpstr)
    break # exit loop
  end

  # calc amout
  target_amount = base_use_amount.to_f / tmp_target_price.to_f

  # display
  tmpstr = Time.now.to_s + ' ' + BASE_COINNAME + ' の残高は '
  tmpstr += base_free_amount.to_s + ' [' + BASE_COINNAME + '] です。'
  tmpstr += TARGET_COINNAME + ' の価格は '
  tmpstr += tmp_target_price.to_s + ' [' + BASE_COINNAME + '] です。'
  tmpstr += TARGET_COINNAME + ' の購入数量は '
  tmpstr += target_amount.to_s + 'です。'
  LOG.info(object_id, self.class.name, __method__, tmpstr)
  puts(tmpstr)

  # order
  redo if raw_create_order(COINPAIR, target_amount, tmp_target_price, SIDE).nil?
  # update 'lastbuy.yaml'
  save_last_trading(TARGET_COINNAME, target_amount, tmp_target_price)
end
puts('プログラムを終了しました。')
