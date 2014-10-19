module LgdLog
  def warn(message=nil)
    high_log ||= Logger.new("#{Rails.root}/log/lgd_high.log")
    high_log.warn(message) unless message.nil?
  end
	
	def info(message=nil)
		high_log ||= Logger.new("#{Rails.root}/log/lgd_high.log")
		high_log.info(message) unless message.nil?
	end
	
	def log(message=nil)
		low_log ||= Logger.new("#{Rails.root}/log/lgd_low.log")
		low_log.debug(message) unless message.nil?
	end
end