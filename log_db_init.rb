#!/opt/ruby_2.2.3/bin/ruby -w
# coding: utf-8

require "mysql"
数据库IP='127.0.0.1'
数据库用户='root'
数据库密码=''
数据库名称='sendmsg'
数据库连接 = Mysql::new(数据库IP, 数据库用户, 数据库密码, 数据库名称)
数据库连接.query("SET NAMES 'utf8';"); #这个最好都加上。否则可能执行不成功，但是也不报错

if ARGV[0] == nil
	puts "请出入init参数";
	exit;
end
def 初始化数据库结构(数据库连接参数,初始化SQL)
	初始化SQL.each_line(sep=';') {|sql | p sql ;数据库连接参数.query(sql); }
	puts "初始化完成"
	exit 0
end
p __dir__
初始化数据库结构(数据库连接,File.open("#{__dir__}/config/init.sql","r")) if ARGV[0] == 'init'
