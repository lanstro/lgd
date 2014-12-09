module LgdLog
  def warn(message=nil)
    high_log ||= Logger.new("#{Rails.root}/log/lgd_high.log", 10, 100.megabytes)
    high_log.warn(message) unless message.nil?
		log message
  end
	
	def info(message=nil)
		high_log ||= Logger.new("#{Rails.root}/log/lgd_high.log", 10, 100.megabytes)
		high_log.info(message) unless message.nil?
	end
	
	def log(message=nil)
		low_log ||= Logger.new("#{Rails.root}/log/lgd_low.log", 10, 100.megabytes)
		low_log.debug(message) unless message.nil?
	end
end