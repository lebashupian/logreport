-- 注意,ruby是以 分号 为分隔符来读取文件的，所以建表语句末尾一定要加上分号
CREATE TABLE `messages` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `批次` bigint(20) DEFAULT NULL,
  `uuid` varchar(100) DEFAULT NULL,
  `时间` datetime DEFAULT NULL,
  `ip` varchar(20) DEFAULT NULL,
  `日志` varchar(512) DEFAULT NULL,
  `信息` varchar(2048) DEFAULT NULL,
  `发送状态` int(2) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=426 DEFAULT CHARSET=utf8;
--
CREATE TABLE `msg_receiver` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `name` varchar(15) DEFAULT NULL,
  `cellphone` varchar(20) DEFAULT NULL,
  `email` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8
