# log for kkt

# standerd library require
require 'logger'

# log for kkt
class KktLog < Logger
  # write enabele/disable
  attr_accessor :enable

  # make log message
  def make_message(object_id, class_name, method_name, message)
    tmp = object_id.to_s
    tmp += ' ' + class_name.to_s
    tmp += ' ' + method_name.to_s
    tmp += ' ' + message.to_s
    tmp # return(tmp)
  end

  def debug(object_id, class_name, method_name, message)
    return unless @enable
    super(make_message(object_id, class_name, method_name, message))
  end

  def info(object_id, class_name, method_name, message)
    return unless @enable
    super(make_message(object_id, class_name, method_name, message))
  end

  def warn(object_id, class_name, method_name, message)
    return unless @enable
    super(make_message(object_id, class_name, method_name, message))
  end

  def error(object_id, class_name, method_name, message)
    return unless @enable
    super(make_message(object_id, class_name, method_name, message))
  end

  def fatal(object_id, class_name, method_name, message)
    return unless @enable
    super(make_message(object_id, class_name, method_name, message))
  end

  def unknown(object_id, class_name, method_name, message)
    return unless @enable
    super(make_message(object_id, class_name, method_name, message))
  end
end
