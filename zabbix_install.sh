#!bin/bash

#https://raw.githubusercontent.com/mrchenbr/bash/master/zabbix_install.sh

read -p "Enter MariaDB Password: " DB_ROOT_PSWD
read -p "Enter Zabbix  Password: " ZABBIX_PSWD
#DB_ROOT_PSWD=`date|md5sum|cut -c 2-9` # 获取随机数当做密码

IPADDR=`ip route | tail -1 | awk '{print $9}'`

install_lamp(){
sed -i s'#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
setenforce 0
#关闭防火墙,生产环境中自行放行
# systemctl stop firewalld >/dev/null
# systemctl disable firewalld >/dev/nulls
firewall-cmd --add-service=http --permanent
firewall-cmd --reload
echo "Initialize the LAMP environment, please wait....."
yum install php php-mysql httpd mariadb mariadb-server -y >/dev/null
echo "install LAMP done!"
}

install_MariaDB() {

echo "Initialize DB..." 
# 启动并使其随机启动
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

echo "install zabbix..."
yum install zabbix-server-mysql zabbix-web-mysql zabbix-agent -y >/dev/null

echo "Create Database..."
mysql -uroot -p${DB_ROOT_PSWD} -e "create database zabbix character set utf8 collate utf8_bin"
mysql -uroot -p${DB_ROOT_PSWD} -e "CREATE USER zabbix@localhost IDENTIFIED BY \"${ZABBIX_PSWD}\"";
mysql -uroot -p${DB_ROOT_PSWD} -e "GRANT ALL ON zabbix.* TO 'zabbix'@'localhost' identified by \"${ZABBIX_PSWD}\"; flush privileges"

# 测试数据库是否部署成功
mysql -uroot -p${DB_ROOT_PSWD} -e 'show databases'
echo "import zabbix sql..."
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -p${ZABBIX_PSWD} zabbix
mysql -uzabbix -p${ZABBIX_PSWD} -e "use zabbix; select alias from zabbix.users"

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
echo "------------------------------------------"
echo ""
echo "MariaDB Password : [${DB_ROOT_PSWD}]" > /root/.dbpassword
echo " Zabbix Password : [${ZABBIX_PSWD}]" >> /root/.dbpassword
cat ./.dbpassword
echo "Install done!"
echo "Web:http://${IPADDR}/zabbix"
echo ""
echo "------------------------------------------"
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
install_lamp
install_MariaDB
install_zabbix
service_start
echo_pswd
}
main








