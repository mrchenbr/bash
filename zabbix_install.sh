#!bin/bash

read -p "Enter MariaDB Password: " DB_ROOT_PSWD
read -p "Enter Zabbix  Password: " ZABBIX_PSWD

lamp_install(){
	sed -i s'#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
	setenforce 0
	#关闭防火墙,生产环境中自行放行
	systemctl stop firewalld >/dev/null
	systemctl disable firewalld >/dev/null
	echo "安装LAMP环境,可能需要几分钟,请耐心等待......."
	yum install php php-mysql httpd mariadb mariadb-server -y >/dev/null
	echo "安装LAMP完成!"
}

install_MariaDB() {
    #DB_ROOT_PSWD=`date|md5sum|cut -c 2-9` # 获取随机数当做密码
    echo "初始化DB." # 启动并使其随机启动
    systemctl enable mariadb.service >/dev/null
    systemctl start mariadb.service >/dev/null

# 初始化 MariaDB
mysql_secure_installation <<EOF

Y
${DB_ROOT_PSWD}
${DB_ROOT_PSWD}
Y
Y
Y
Y
EOF
}
install_zabbix(){
	
	echo "安装zabbix"
	yum install zabbix-server-mysql zabbix-web-mysql zabbix-agent -y >/dev/null

	echo "创建数据库"
	mysql -uroot -p${DB_ROOT_PSWD} -e "create database zabbix character set utf8 collate utf8_bin"
	mysql -uroot -p${DB_ROOT_PSWD} -e "CREATE USER zabbix@localhost IDENTIFIED BY \"${ZABBIX_PSWD}\"";
	mysql -uroot -p${DB_ROOT_PSWD} -e "GRANT ALL ON zabbix.* TO 'zabbix'@'localhost' identified by \"${ZABBIX_PSWD}\"; flush privileges"
	
	# 测试数据库是否部署成功
	-uroot -p${DB_ROOT_PSWD} -e 'show databases'
	
	echo "导入数据"
	zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -p${ZABBIX_PSWD} zabbix
	mysql -uzabbix -p${ZABBIX_PSWD} -e "use zabbix; select alias from zabbix.users"
	echo "查询到用户表,代表zabbix表导入成功"
	
	#配置zabbix_server.conf ,采用的默认,当前只修改DBPassword和DBHost
	# DBPassword=zabbix
	# DBHost=localhost
	# DBName=zabbix
	# DBUser=zabbix
	sed -i s'#\# DBPassword=#DBPassword=zabbix#g' /etc/zabbix/zabbix_server.conf
	sed -i s'#\# DBHost=localhost#DBHost=localhost#g' /etc/zabbix/zabbix_server.conf
	#修改时区
	sed -i s'#\# php_value date.timezone Europe/Riga#php_value date.timezone Asia/Shanghai#g' /etc/httpd/conf.d/zabbix.conf
}
echo_pswd(){
	echo ""
	echo "安装完成!请访问http://IP/zabbix!"
	echo ""
	echo "MariaDB Password : [${DB_ROOT_PSWD}]" > /root/.dbpassword
	echo " Zabbix Password : [${ZABBIX_PSWD}]" >> /root/.dbpassword
	cat ./.dbpassword
	echo ""
}

service_start(){
	systemctl start httpd
	systemctl enable httpd
	systemctl start zabbix-server 
	systemctl enable zabbix-server 
	systemctl start zabbix-agent
	systemctl enable zabbix-agent 
	systemctl restart httpd
}

main(){
	lamp_install
	install_MariaDB
	install_zabbix
	service_start
	echo_pswd
}
main




