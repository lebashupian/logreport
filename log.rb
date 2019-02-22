#!/opt/ruby_2.2.3/bin/ruby
# coding: utf-8

数组=[]
#i=1
f=File.open("/home/ruby/access_log.bak.2",'r');
ip哈希={}
f.each_line {|x|
#p x 正则结果=Regexp.new('"\d{1,}\.\d{1,}"').match(x)
if ! Regexp.new('Zabbix').match(x) and ! Regexp.new('yunlianjie').match(x)
	#p x
	if Regexp.new(' 404 ').match(x) != nil
		#p Regexp.new(' 404 ').match(x) 
		ip=Regexp.new('(\d{1,}\.){3}\d{1,3}').match(x)[0]
		if ip哈希.has_key?(ip)
			i=ip哈希[ip]
			i += 1
			tmp={ ip => i }
		else
			tmp={ ip => 1 }
		end
		#p tmp
		ip哈希.merge!(tmp)
	end
	
	#sleep 1

end
}

ip哈希.each {|x|
	next if x[1] <= 10
	`iptables -I INPUT -s #{x[0]} -p tcp --dport 80 -j ACCEPT` 
}



#p 数组.uniq!
#
#
=begin
	a=x.split('@@@');
	if a.size == 10
		长度 = a[9].chomp.strip.size
		数字=  a[9].chomp.strip.slice(1,长度-2).to_f
		url=a[3]
		时间=a[2]
		ip地址=a[0]
		状态=a[4].strip
		# 数字.class
		#p 数字
		if  数字 >= 0 and 状态 != '404'; 
			#puts 数字 
			#数组 << 数字
			print "#{i},#{ip地址},#{时间},#{url},#{状态},#{数字}\n"
			i += 1
			#puts url
			#puts 数字
		end

	end
=end
