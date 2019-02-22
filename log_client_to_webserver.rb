#!/opt/ruby_2.4.0/bin/ruby
# coding: utf-8
require 'json'
require 'socket'
require 'uuid'
require 'yaml'

require 'uri'
require 'net/http'



######################################################、
# 新帮助提示
######################################################
if ARGV[0] == nil or ARGV[0] == "help" or ARGV[0] == "--help"
puts '
################################################################################################
#  --help           :   显示帮助信息
#  --logfile        :   指定监控的日志文件
#                       特殊的值：config,指的是使用配置文件中定义的log文件
#  --local_host     :   指定本地主机的地址，这个用来表明信息来自于何处，可以是字符串或IP地址
#  --remote_server  :   用来指定发送数据到哪个服务器，这个必须指定IP地址
#  --regexp         :   用来指定匹配数据时，使用的正则表达式
#                       默认值是.*,这个是不包括行尾的，如果要包括行尾，需要指定正则表达式为.*\n
#  --use_logserver  :   使用tcp socket将信息发送到logserver中，默认不使用，可设置的值是 yes no
#  --use_webserver  :   使用web api 将信息发送到webserver中，默认使用，可设置的值是 yes no
#  --debug          :   使用debug功能输出一些调试信息，默认是yes
#  
#  日志文件最好使用绝对路径
#  范例1:
#  logreport.rb --logfile=/var/log/messages --local_host=CeshiHost --remote_server=192.168.137.37 --regexp=.*
#  范例2:
#  logreport.rb --logfile=config --local_host=CeshiHost --remote_server=192.168.137.37 --regexp=.*
################################################################################################
'
exit
end


#######################################################
# 脚本参数处理
#######################################################
# 首先设置默认值
脚本参数hash表={}
脚本参数hash表["--log_file"]="config"
脚本参数hash表["--local_host"]="localhost"
脚本参数hash表["--remote_server"]="192.168.137.37"
脚本参数hash表["--regexp"]=".*"
脚本参数hash表["--use_logserver"]="no"
脚本参数hash表["--use_webserver"]="yes"
脚本参数hash表["--debug"]="yes"
# 使用脚本的参数赋值重新覆盖默认参数
ARGV.each {|x|
  脚本参数hash表.merge!({"#{x.split("=")[0]}" => "#{x.split("=")[1]}"});
}

#####################################################
# 判断参数的合法性
#####################################################
if 脚本参数hash表["--log_file"] != "config"
	(puts "日志文件不存在";exit 10) if File.exist?(脚本参数hash表["--log_file"])
end

####################################################
# 变量赋值
####################################################
服务器IP      =  脚本参数hash表["--remote_server"]
日志文件参数   =  脚本参数hash表["--log_file"]
输出正则      =  脚本参数hash表["--regexp"]
本地IP        = 脚本参数hash表["--local_host"]
启用logserver = 脚本参数hash表["--use_logserver"]
启用webserver = 脚本参数hash表["--use_webserver"]
#########################################################
# 加载配置文件
# 并让配置文件能实时修改实时生效
# 注意由于个别原因，无法支持所有的参数都实时生效
YAML_FILE="#{__dir__}/config/config.yml"
配置文件=nil  #让配置文件能被全局读
Thread.new {
	loop {
	配置文件=YAML.load(File.open(YAML_FILE,'r'));
	sleep 2  #p配置文件reload的时间
	}
}
sleep 2  #这里对上面的代码执行稍作等待
#########################################################
#配置文件中的日志文件参数处理
日志文件参数_hash={}
if  日志文件参数 == 'config'
	日志文件参数_hash = 配置文件["log_file"]
	use_config = 'yes'
end
#######################################################
#  连接消息接受服务器的地址
#######################################################
if 启用logserver == 'yes'
	begin 
		消息服务器 = TCPSocket.open(服务器IP,19001)
	rescue Exception => 异常
		puts "无法连接#{服务器IP}的 19001 端口 退出";
		exit 105
	end
end

begin
	批次戳=Time.new.to_i

	if use_config == 'yes' && 日志文件参数_hash.size != 0
		打开文件_hash={}
		日志文件参数_hash.each_pair {|文件序列,序列项|
			p 文件序列 ; p 序列项["path"] ; p 序列项["owner"]
			打开文件_hash["#{序列项['path']}"]=File.open(序列项["path"],"r")
			打开文件_hash["#{序列项['path']}"].seek(0,IO::SEEK_END)	
		}
		p 打开文件_hash
		线程数组=[]
		日志文件参数_hash.each_pair {|文件序列,序列项|

			文件路径=序列项['path']
			文件所有者=序列项['owner']

			线程数组 << Thread.new {
				loop {
					begin
						时间戳=Time.new.to_s.slice(0,19)
					    行=打开文件_hash["#{文件路径}"].readline
					    正则结果=Regexp.new(输出正则).match(行)
					    批次uuid=UUID.new.generate
					    文件所有着=配置文件["log_file"]["relink_to_server"]
					    发送消息="user"+"----"+"pwd"+"----"+"#{批次戳}"+"@@@"+"#{批次uuid}"+"@@@"+"#{时间戳}"+"@@@"+"#{本地IP}"+"@@@"+"#{文件路径}"+"@@@"+"#{文件所有者}"+"@@@"+正则结果[0]
					    p 发送消息 if 脚本参数hash表["--debug"] == 'yes'


					    #####################
					    # 向消息接受服务器发送消息
					    #####################
					    if 启用logserver == 'yes'
							begin
								消息服务器.puts(发送消息)
							rescue 
								puts "向消息服务器#{服务器IP}发送消息失败,重试...."

								begin
						    		消息服务器 = TCPSocket.open(服务器IP,19001)
						    	rescue Exception => 异常
						    		puts "重连#{服务器IP}重试中..."
						    		sleep 配置文件["delay"]["relink_to_server"]  #重新连接主机的延迟
						    		retry
						    	end

								retry
							end
						end
					    #####################
					    # 向web api 发送消息
					    #####################
					    if 启用webserver == 'yes'
						    begin
						    	require 'json'
						    	require 'uri'
						    	require 'net/http'
								Net::HTTP.post_form   URI("http://#{配置文件['apiserver']['host']}:8888/msgs/postdata/"),
													{ "时间" => "#{时间戳}" , "来源" => "#{本地IP}" , "文件" => "#{文件路径}", "所有者" => "#{文件所有者}","消息" => "#{正则结果[0]}" ,"状态" => "N"}
						    rescue Exception => 异常
						    	puts "无法向web API正常发送消息，开始重新连接#{服务器IP}"
						    	sleep 配置文件["delay"]["relink_to_server"]  #重新连接主机的延迟
						    	retry
						    end	
						end
					rescue Exception => 异常
					    puts "#{时间戳} #{文件序列} #{文件路径} 等待日志文件更新....." if 脚本参数hash表["--debug"] == 'yes'
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
		"程序遇到未知的运行状态"
		exit 105
	end
rescue Exception => 异常
	puts 异常.message
end