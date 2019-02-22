#!/opt/ruby_2.2.3/bin/ruby -w
require 'socket'               # 获取socket标准库
require "mysql"
require 'net/smtp'
require 'json'
require 'uri'
require 'net/http'
require 'yaml'

YAML_FILE="#{__dir__}/config/config.yml"
配置文件=YAML.load(File.open(YAML_FILE,'r'));

#是否开启信息输出
debug=true


数据库IP='127.0.0.1'
数据库用户='root'
数据库密码=''
数据库名称='sendmsg'

数据库连接 = Mysql::new(数据库IP, 数据库用户, 数据库密码, 数据库名称)
数据库连接.query("SET NAMES 'utf8';"); #这个最好都加上。否则可能执行不成功，但是也不报错


if ARGV[0]  != nil && ARGV[1]  != nil
	用户名,密码=ARGV[0],ARGV[1]
else
	用户名,密码="user","pwd"
end


=begin
create database sendmsg;
create table messages (
id int(10) AUTO_INCREMENT not null,
批次 bigint,
uuid varchar(100),
时间 datetime,
ip varchar(20),
日志 varchar(512),
信息 varchar(2048),
发送状态 int(2) not null default 0,
PRIMARY KEY(id)
) DEFAULT CHARSET=utf8;
=end

=begin
create table msg_receiver (
id int(10) AUTO_INCREMENT not null,
name varchar(15),
cellphone varchar(20),
email varchar(50),
PRIMARY KEY(id)
) DEFAULT CHARSET=utf8;
=end

#
#echo -e -n "user---pwd---192.168.0.1@@@`date +%F`@@@`date +%T`@@@ceshi" > /dev/tcp/127.0.0.1/19001
#

###############################################################
#  发送报警线程
###############################################################
Thread.new {
	loop {
		批次=数据库连接.query("select distinct(批次) from messages where 发送状态=0");
		批次.each {|批次号|
			批次号 = 批次号[0]
			条目=数据库连接.query("select id,批次,uuid,时间,ip,日志,信息 from messages where 批次=\"#{批次号}\"");
			邮件_id  ='';
			邮件_批次='';
			邮件_uuid='';
			邮件_时间='';
			邮件_ip  ='';
			邮件_日志='';
			邮件_信息='';
			条目.each {|单条|
				邮件_id=单条[0]
				邮件_批次=单条[1]
				邮件_uuid=单条[2]
				邮件_时间=单条[3]
				邮件_ip=单条[4]
				邮件_日志=单条[5].force_encoding("UTF-8")
				邮件_信息 += 单条[6].force_encoding("UTF-8") #通过 += 累加信息
			}
			p 	邮件_批次,邮件_日志,邮件_信息 if debug == true

			#生成联系人列表
			手机列表=[]
			邮箱列表=[]
			联系人数据=数据库连接.query("select * from msg_receiver");
			联系人数据.each {|行|
				手机列表 << 行[2]
				邮箱列表 << 行[3]
			}
			p "手机列表 => ",手机列表 if debug == true
			p "邮箱列表 => ",邮箱列表 if debug == true

			#生成html页面
			htmlserver=配置文件["htmlserver"]["url"]
			htmldir=配置文件["htmlserver"]["dir"]
			htmlfile=File.new("#{htmldir}/#{邮件_uuid}.txt","w+");
			htmlfile.write("报警服务：logerror\n");
			htmlfile.write("报警时间：#{邮件_时间}\n");
			htmlfile.write("服务器IP：#{邮件_ip}\n");
			htmlfile.write("日志名称：#{邮件_日志}\n");
			htmlfile.write("内容详情：\n#{邮件_信息}\n");
			htmlfile.close;

			Net::SMTP.start(配置文件["mail"]["smtp_server_host"], 配置文件["mail"]["smtp_server_port"]) do |smtp|
			  smtp.open_message_stream('process@ruby', 邮箱列表) do |f|
			    f.puts 'Subject: log报警服务'
			    f.puts
			    f.puts "报警服务：logerror"
			    f.puts "报警时间：#{邮件_时间}"
			    f.puts "服务器IP：#{邮件_ip}"
			    f.puts "日志名称：#{邮件_日志}"
			    f.puts "内容详情：\n#{邮件_信息}"
			    f.puts "内容链接：#{htmlserver}/#{邮件_uuid}.txt"
			  end         
			end


=begin
			puts "发送短信...." if debug == true
			短信uri = URI('http://api-dev.lejian.net/intranet/message/send/')
			Net::HTTP.start(短信uri.host, 短信uri.port,:read_timeout => 2,:continue_timeout => 4) do |http实例|
			  请求 = Net::HTTP::Post.new(短信uri.path, 'Content-Type' => 'application/json')
			  #["#{htmlserver}/#{邮件_uuid}.txt", "abc"],
			  请求.body ={"msg_content" => ["lejianbao-celery-worker-error.log 报错", "abc"],
			  			  "fun_name" => "retrieve_password",
			  			  "app_name"=> "api",
			  			  "msg_type"=> "SMS",
			  			  "receivers"=> 手机列表
			  			  }.to_json
			  puts 请求.body  if debug == true
			  http实例.set_debug_output $stderr
			  返回结果 = http实例.request 请求 # Net::HTTPResponse object
			  puts "结果 ：#{返回结果.body}"
			end
			puts "发送短信..end" if debug == true
=end
			数据库连接.query("update messages set 发送状态=1 where 批次=\"#{批次号}\"");
			数据库连接.query("commit");
		}
		puts "#{Time.new} 批次循环完毕" if debug == true
		sleep 配置文件["delay"]["log_server_check"]
	}
}
###############################################################
#  消息接受线程
###############################################################
消息服务器 = TCPServer.open(19001)   # Socket 监听端口为 19001
p 消息服务器
loop {                          # 永久运行服务
	
  	Thread.start(消息服务器.accept) do |socket对象|
  			loop {
	 			字符串  =socket对象.gets  #读取link这个socket连接中的数据
	 			字符串.force_encoding("UTF-8")
				#p 字符串
				数组    =字符串.split(/----/) #用--------来分割数据为数组对象
				#p 数组
				认证名  =数组[0]   #获取认证名
				认证密码=数组[1]   #获取认证密码
				数据    =数组[2]   #获取字符串数据
				#p 数据
				if 认证名 == 用户名 && 认证密码 == 密码
					#puts "认证通过"
					数据_数组=数据.split(/@@@/)  #用@@@来分割数据
					数据_数组_批次    =数据_数组[0]
					数据_数组_uuid    =数据_数组[1]
					数据_数组_时间    =数据_数组[2]
					数据_数组_IP      =数据_数组[3]
					数据_数组_日志路径=数据_数组[4]
					数据_数组_日志所有者=数据_数组[5]
					数据_数组_日志内容=数据_数组[6]
					数据库连接.query("SET NAMES 'utf8';");
					sql语句=%Q{insert into messages (批次,uuid,时间,ip,日志,所有者,信息) values(#{数据_数组_批次},'#{数据_数组_uuid}','#{数据_数组_时间}','#{数据_数组_IP}','#{数据_数组_日志路径}','#{数据_数组_日志所有者}','#{数据_数组_日志内容}')}
					puts  sql语句
					数据库连接.query(sql语句);
					数据库连接.query("commit");
					#puts "---------------------------"
				else
					puts "认证失败 : #{数组}"
				end
				#socket对象.close      #关闭这个socket 				
  			}

  	end
  	puts "新连接接入" if debug == true
}
