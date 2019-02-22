#!/opt/ruby_2.2.3/bin/ruby -w
# coding: utf-8
require 'json'
require 'socket'
require 'uuid'
require 'yaml'

YAML_FILE="#{__dir__}/config/config.yml"
配置文件=YAML.load(File.open(YAML_FILE,'r'));

#################################################################################
#  日志文件最好使用绝对路径
#  范例1：logerror.rb /var/log/messages 192.168.0.123 192.168.0.100
#  范例2：logerror.rb /var/log/messages 192.168.0.123 192.168.0.100 "error"
#################################################################################

if ARGV[0] == nil && ARGV[1] == nil && ARGV[2] ==nil
	puts '
		日志文件最好使用绝对路径
 		范例1：logerror.rb /var/log/messages 本机地址 远程服务器地址  "正则表达式(可选)"
 		范例2：logerror.rb /var/log/messages 192.168.0.123 192.168.0.100 "error"
	'

	exit 99
end

if ARGV[0] != nil && File.exist?(ARGV[0])
	日志文件参数=ARGV[0]
elsif ARGV[0] == "nil"
	puts "没有指定日志参数，启用config.yml文件中定义的日志文件"
else
	puts "日志文件参数错误"
	exit 100	
end

if ARGV[1] == nil
	puts "没有指定本机IP地址"
	exit 103
else
	本地IP=ARGV[1]
end

if ARGV[2] == nil
	puts "没有指定接收服务器IP地址"
	exit 104
else
	服务器IP=ARGV[2]
end

if ARGV[3] == nil
	puts "使用默认正则表达式，匹配所有"
	输出正则='.*'    #默认，不包括行尾
	#输出正则='.*.\n' #默认，包括行尾
else
	输出正则=ARGV[3]
end


########
# 命令行日志文件参数处理
日志文件=File.open(日志文件参数,"r") if 日志文件参数 != nil
日志文件.seek(0,IO::SEEK_END)       if 日志文件参数 != nil


########
#配置文件中的日志文件参数处理
日志文件参数_hash={}
if 日志文件参数 == nil
	日志文件参数_hash = 配置文件["log_file"]
	use_config = 'yes'

end

begin 
	消息服务器 = TCPSocket.open(服务器IP,19001)
rescue Exception => 异常
	puts "无法连接#{服务器IP}的 19001 端口 退出";
	exit 105
end



begin
	批次戳=Time.new.to_i

	if use_config == 'yes' && 日志文件参数_hash.size != 0
		打开文件_hash={}
		日志文件参数_hash.each_pair {|文件序列,文件路径|
			打开文件_hash["#{文件路径}"]=File.open(文件路径,"r")
			打开文件_hash["#{文件路径}"].seek(0,IO::SEEK_END)	
		}
		线程数组=[]
		日志文件参数_hash.each_pair {|文件序列,文件路径|


			线程数组 << Thread.new {
				loop {
					begin
						时间戳=Time.new.to_s.slice(0,19)
					    行=打开文件_hash["#{文件路径}"].readline
					    #next if 打开文件_hash["#{文件路径}"].lineno <= 100
					    正则结果=Regexp.new(输出正则).match(行)
					    批次uuid=UUID.new.generate
					    发送消息="user"+"----"+"pwd"+"----"+"#{批次戳}"+"@@@"+"#{批次uuid}"+"@@@"+"#{时间戳}"+"@@@"+"#{本地IP}"+"@@@"+"#{文件路径}"+"@@@"+正则结果[0]
					    p 发送消息
					    begin 
					    	消息服务器.puts(发送消息)
					    rescue Exception => 异常
					    	puts "无法正常发送消息，开始重新连接#{服务器IP}"
					    	begin
					    	消息服务器 = TCPSocket.open(服务器IP,19001)
					    	rescue Exception => 异常
					    		puts "连接#{服务器IP}重试中..."
					    		sleep 配置文件["delay"]["relink_to_server"]  #重新连接主机的延迟
					    		retry
					    	end
					    	retry
					    end	
					rescue Exception => 异常
					    puts "#{时间戳} #{文件序列} #{文件路径} 等待日志文件更新....."
					    sleep 配置文件["delay"]["batch_delay"]
					    批次戳=Time.new.to_i
					    retry
					end
				    sleep 配置文件["delay"]["foreach_delay"] #发送行延迟，主要是为了不给远端的进程太大的压力
				}
			}
			
		}
		线程数组.each {|x| p x.join}

	elsif use_config == 'yes' && 日志文件参数_hash.size == 0
		puts "配置文件中检测到的文件个数为0，请检查配置文件"
		exit 105
	else
		loop {
			begin
				时间戳=Time.new.to_s.slice(0,19)
			    行=日志文件.readline
			    #next if 日志文件.lineno <= 100
			    正则结果=Regexp.new(输出正则).match(行)
			    批次uuid=UUID.new.generate
			    发送消息="user"+"----"+"pwd"+"----"+"#{批次戳}"+"@@@"+"#{批次uuid}"+"@@@"+"#{时间戳}"+"@@@"+"#{本地IP}"+"@@@"+"#{日志文件参数}"+"@@@"+正则结果[0]
			    p 发送消息
			    begin 
			    	消息服务器.puts(发送消息)
			    rescue Exception => 异常
			    	puts "无法正常发送消息，开始重新连接#{服务器IP}"
			    	begin
			    	消息服务器 = TCPSocket.open(服务器IP,19001)
			    	rescue Exception => 异常
			    		puts "连接#{服务器IP}重试中..."
			    		sleep 配置文件["delay"]["relink_to_server"]  #重新连接主机的延迟
			    		retry
			    	end
			    	retry
			    end	
			rescue Exception => 异常
			    puts "#{时间戳} 等待日志文件更新....."
			    sleep 配置文件["delay"]["batch_delay"]
			    批次戳=Time.new.to_i
			    retry
			end
		    #sleep 配置文件["delay"]["foreach_delay"] #发送行延迟，主要是为了不给远端的进程太大的压力
		}	
	end

	


rescue Exception => 异常
	puts 异常.message
	#puts e.backtrace.inspect
end