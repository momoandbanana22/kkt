# kkt.rb - 'kotsukotsuto' - dollar cost averaging bot
PROGRAM_VERSION = 'ver.20180515_1515'.freeze
PROGRAM_NAME = 'kkt'.freeze

# standerd library require
require 'yaml'
require 'date'
require 'bigdecimal'

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
  sleep(RANDOM.rand(1.0) + 1.5) # 1.5[sec] - 2.5[sec]
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
    errstr = "BBCC.read_balance() not success. code=#{res['data']['code']}"
    LOG.error(object_id, self.class.name, __method__, errstr)
    return nil
  end
  res # return res
end

def read_amount
  ret = Hash.new { |h, k| h[k] = {} }
  res = raw_read_balance
  return ret if res.nil?
  res['data']['assets'].each do |one_asset|
    one_asset.each do |key, val|
      ret[one_asset['asset']][key] = val if key != 'asset'
    end
  end
  ret # return ret
end

def free_amout(target_coin)
  tmp = read_amount
  return 0 if tmp.nil?
  tmp[target_coin]['free_amount']
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

def raw_get_price
  res = retry_get_price
  if res['success'] != 1
    errstr = "BBCC.read_ticker() not success. code=#{res['data']['code']}"
    LOG.error(object_id, self.class.name, __method__, errstr)
    return nil
  end
  res # return res
end

def price
  ret = {} # empty hash
  res = raw_get_price
  return ret if res.nil?
  res['data'].each do |key, val|
    ret[key] = val if key != 'success'
  end
  ret # retrun ret
end

def read_target_price
  tmp = price
  return 0 if tmp.nil?
  return(tmp['last']) if SIDE == 'buy'
  1 / tmp['last']
end

########
# order
########

def api_create_order(pair, amount, price, side, type)
  JSON.parse(BBCC.create_order(pair, amount, price, side, type))
rescue StandardError => exception
  LOG.fatal(object_id, self.class.name, __method__, exception.to_s)
  nil # return nil
end

def retry_create_order(pair, amount, price, side, type)
  res = nil
  loop do
    res = api_create_order(pair, amount, price, side, type)
    break unless res.nil?
    random_sleep
  end
  res # return res
end

def raw_create_order(pair, amount, price, side, type)
  res = retry_create_order(pair, amount, price, side, type)
  if res['success'] != 1
    errstr = "BBCC.create_order() not success. code=#{res['data']['code']}"
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
def save_last_trading(target_coinname, amout, price, type)
  lastbuytime = Time.now
  lastbuy = {}
  lastbuy['unixtime'] = lastbuytime.to_i
  lastbuy['coinname'] = target_coinname
  lastbuy['amout'] = amout
  lastbuy['price'] = price
  lastbuy['type'] = type
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

# make limig log str
def limit_log_str(target_price, target_limit_price)
  tmpstr = "#{Time.now} #{TARGET_COINNAME} の価格が "
  tmpstr += "#{target_price} [#{BASE_COINNAME}] で、 "
  tmpstr += "#{target_limit_price} [#{BASE_COINNAME}] を超えています。"
  tmpstr # return tmpstr
end

# check limit price
def limit_price(target_price, target_limit_price)
  ret_type = 'market'
  ret_target_price = target_price
  if target_price > target_limit_price
    tmpstr = limit_log_str(target_price, target_limit_price)
    LOG.info(object_id, self.class.name, __method__, tmpstr)
    puts(tmpstr)
    ret_type = 'limit'
    ret_target_price = target_limit_price
  end
  [ret_type, ret_target_price] # return ret_type, ret_target_price
end

# make log string
def order_log_str(base_free_amount, target_price, target_amount, type)
  tmpstr = "#{Time.now} #{BASE_COINNAME} の残高は #{base_free_amount} "
  tmpstr += "[#{BASE_COINNAME}] です。"
  tmpstr += "#{TARGET_COINNAME} の価格は #{target_price} [#{BASE_COINNAME}] です。"
  if TARGET_COINNAME == 'xrp'
    target_amount = BigDecimal(target_amount.to_s).floor(4).to_f
  end
  tmpstr += "#{TARGET_COINNAME} の購入数量は #{target_amount} です。"
  tmpstr += "注文は #{type} です。"
  tmpstr # retrun tmpstr
end

COINPAIR, SIDE = coinpair_and_side
if COINPAIR.nil?
  LOG.error(
    object_id,
    'main',
    'main',
    '設定ファイルに記述されたコインペアが正しくありません。プログラムを終了しました。'
  )
  exit(-1)
end
LOG.debug(object_id, 'main', 'main', 'setting : coinpair=' +
  COINPAIR + ' side=' + SIDE)

# initialize Bitbankcc Class
APIKEY = YAML.load_file('apikey.yaml')
BBCC = Bitbankcc.new(APIKEY['apikey'], APIKEY['seckey'])

base_use_amount = SETTING['base_coin']['use_amount'].to_f
base_keep_amount = SETTING['base_coin']['keep_amount'].to_f
target_limit_price = SETTING['target_coin']['limit_price'].to_f
program_continue = SETTING['program_continue']

# main loop
loop do
  wait_loop

  # check amout
  target_price = read_target_price.to_f # api access
  base_free_amount = free_amout(BASE_COINNAME).to_f # api access
  if (base_free_amount - base_keep_amount) < base_use_amount
    if !program_continue
      tmpstr = "#{Time.now}  残高が足りないので、プログラムを終了します。"
      tmpstr += "(#{base_free_amount} [#{BASE_COINNAME}])"
      LOG.info(object_id, self.class.name, __method__, tmpstr)
      puts(tmpstr)
      break # exit loop
    else
      tmpstr = "#{Time.now}  残高が足りないので、次のタイミングまで待ちます。"
      tmpstr += "(#{base_free_amount} [#{BASE_COINNAME}])"
      LOG.info(object_id, self.class.name, __method__, tmpstr)
      puts(tmpstr)
      save_last_trading(TARGET_COINNAME, 0, 0, 'wait')
      redo
    end
  end

  # order type and price
  type, target_price = limit_price(target_price, target_limit_price)

  # calc amout
  target_amount = base_use_amount.to_f / target_price

  # order
  loop do
    break unless raw_create_order(
      COINPAIR,
      target_amount,
      target_price,
      SIDE,
      type
    ).nil?
  end

  # update 'lastbuy.yaml'
  save_last_trading(TARGET_COINNAME, target_amount, target_price, type)

  # display & log
  tmpstr = order_log_str(base_free_amount, target_price, target_amount, type)
  LOG.info(object_id, self.class.name, __method__, tmpstr)
  puts(tmpstr)
end
puts('プログラムを終了しました。')
