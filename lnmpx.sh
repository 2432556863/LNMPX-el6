#!/bin/bash
#作者：Areturn
#QQ:2432556863
#一键安装lnmpx环境
##########
appdir=/application/
webdb=${appdir}mysql/data
nginx_download="http://nginx.org/download/nginx-1.10.3.tar.gz"
nginx_name="`basename $nginx_download`"
mysql_download="https://downloads.mysql.com/archives/get/file/mysql-5.6.34-linux-glibc2.5-x86_64.tar.gz"
mysql_name="`basename $mysql_download`"
php_download="http://php.net/distributions/php-5.5.32.tar.gz"
php_name="`basename $php_download`"
xcache_download="http://xcache.lighttpd.net/pub/Releases/3.2.0/xcache-3.2.0.tar.gz"
xcache_name="basename $xcache_download"
web_user=www
web_uid=666
cpu_num=`lscpu|awk '/^CPU\(s\)/{print $2*2}'`
host_name=www.areturn.com
##########更换阿里云源
if [ ! `yum repolist|grep -c 'mirrors.aliyun.com'` -ge 4 ];then
	wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-6.repo
	wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-6.repo
	clear
	echo "aliyum repo install 完成！"
fi
##########Nginx install
Nginx_install(){
if [ ! -d "$appdir${nginx_name/.tar*/}/" ];then
	if ! rpm -q pcre-devel openssl-devel &>/dev/null;then
		yum install -y pcre-devel openssl-devel 
		clear
		echo "Nginx依赖安装完成！"
	fi
	wget -c $nginx_download&&echo "nginx安装包下载完成"
	if ! id $web_user >/dev/null;then
		useradd -s /sbin/nologin -M -u $web_uid $web_user &&echo "$web_user用户添加成功！"
	else
		id $web_user|grep -q "uid=$web_uid"
		[ $0 -ne 0 ]&&userdel -r $web_user&&useradd -s /sbin/nologin -M -u $web_uid $web_user &&echo "$web_user用户添加成功！"
	fi
	tar xf $nginx_name
	cd ${nginx_name/.tar*/}
	./configure --prefix=${appdir}${nginx_name/.tar*/} --user=www --group=www --with-http_stub_status_module --with-http_ssl_module
	[ $? -eq 0 ]&&make -j $cpu_num&&make install
	if [ $? -eq 0 ];then
		echo "${nginx_name/.tar*/}安装完成！"
	else
		echo "${nginx_name/.tar*/}安装失败！退出"
		exit 1
	fi
	if [ -d "${appdir}nginx" ];then
		rm -f ${appdir}nginx
		ln -sv $appdir${nginx_name/.tar*/}/ ${appdir}nginx
	else
		ln -sv $appdir${nginx_name/.tar*/}/ ${appdir}nginx
	fi
	if [ -f "/usr/local/sbin/nginx" ];then
		rm -f /usr/local/sbin/nginx
		ln -sv ${appdir}nginx/sbin/nginx /usr/local/sbin
	else
		ln -sv ${appdir}nginx/sbin/nginx /usr/local/sbin
	fi
	grep -q "^${appdir}nginx/sbin/nginx$" /etc/rc.local||echo "${appdir}nginx/sbin/nginx" >>/etc/rc.local
	cd ..
	rm -fr ${nginx_name/.tar*/}
else
	echo "${nginx_name/.tar*/}已安装！"
fi
	Mysql_install
}
##########Mysql install
Mysql_install(){
if [ ! -d "${appdir}${mysql_name/-linux*/}/" ];then
	if ! id mysql &>/dev/null;then
		useradd -s /sbin/nologin -M mysql
		[ $? -eq 0 ]&&echo "mysql用户添加完成！"
	fi
	wget -c $mysql_download&&echo "${mysql_name/-linux*/}安装包下载完成！"
	tar xf $mysql_name
	mv ${mysql_name/.tar*/} ${appdir}${mysql_name/-linux*/}
	if [ -d "${appdir}mysql/" ];then
		rm -f ${appdir}mysql
		ln -s ${appdir}${mysql_name/-linux*/} ${appdir}mysql
	else
		ln -s ${appdir}${mysql_name/-linux*/} ${appdir}mysql
	fi
	chown -R mysql.mysql ${appdir}mysql/
	${appdir}mysql/scripts/mysql_install_db --basedir=${appdir}mysql --datadir=$webdb --user=mysql
	if [ $? -eq 0 ];then
		echo "${mysql_name/-linux*/}安装完成！"
	else
		echo "${mysql_name/-linux*/}安装失败！退出"
		exit 1
	fi
	chown -R root ${appdir}mysql/
	chown -R mysql.mysql $webdb
	cp ${appdir}mysql/support-files/mysql.server  /etc/init.d/mysqld
	chmod +x /etc/init.d/mysqld
	eval sed -i 's#/usr/local/mysql#${appdir}mysql#g' ${appdir}mysql/bin/mysqld_safe /etc/init.d/mysqld
	chkconfig --add mysqld 
	chkconfig mysqld on
	[ -f "/etc/my.cnf" ]&&mv /etc/my.cnf /etc/my.cnf.`date +%F_%T`&&cp ${appdir}mysql/support-files/my-default.cnf /etc/my.cnf
	grep -q "export PATH=${appdir}mysql/bin"':$PATH' /etc/profile||echo "export PATH=${appdir}mysql/bin"':$PATH' >>/etc/profile
	rm -fr ${mysql_name/.tar*/}
else
	echo "${mysql_name/-linux*/}已安装！"
fi
	PHP_install
}
########PHP install
PHP_install(){
if [ ! -d "${appdir}${php_name/.tar*/}/" ];then
	yum install zlib-devel libxml2-devel libjpeg-devel libjpeg-turbo-devel libiconv-devel libmcrypt-devel -y
	yum install freetype-devel libpng-devel gd-devel libcurl-devel libxslt-devel libxslt-devel libmcrypt-devel -y
	yum -y install libmcrypt-devel mhash mcrypt
	if [ ! -d "/usr/local/libiconv" ];then
		wget -c http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
		tar xf libiconv-1.14.tar.gz
		cd libiconv-1.14
		./configure --prefix=/usr/local/libiconv
		make -j $cpu_num && make install
		cd ..
		rm -fr libiconv-1.14
	fi
	clear
	echo "PHP依赖安装完成！"
	wget -c $php_download&&echo "${php_name/.tar*/}安装包下载完成！"
	tar xf $php_name
	cd ${php_name/.tar*/}
	./configure \
	--prefix=${appdir}${php_name/.tar*/} \
	--with-mysql=${appdir}mysql/ \
	--with-pdo-mysql=mysqlnd \
	--with-iconv-dir=/usr/local/libiconv \
	--with-freetype-dir \
	--with-jpeg-dir \
	--with-png-dir \
	--with-zlib \
	--with-libxml-dir=/usr \
	--enable-xml \
	--disable-rpath \
	--enable-bcmath \
	--enable-shmop \
	--enable-sysvsem \
	--enable-inline-optimization \
	--with-curl \
	--enable-mbregex \
	--enable-fpm \
	--enable-mbstring \
	--with-mcrypt \
	--with-gd \
	--enable-gd-native-ttf \
	--with-openssl \
	--with-mhash \
	--enable-pcntl \
	--enable-sockets \
	--with-xmlrpc \
	--enable-soap \
	--enable-short-tags \
	--enable-static \
	--with-xsl \
	--with-fpm-user=$web_user \
	--with-fpm-group=$web_user \
	--enable-ftp \
	--enable-opcache=no
	if [ $? -eq 0 ];then
		ln -s /application/mysql/lib/libmysqlclient.so.18  /usr/lib64/ &>/dev/null
		touch ext/phar/phar.phar
		make -j $cpu_num&&make install
		if [ $? -eq 0 ];then
			echo "${php_name/.tar*/}安装完成!"
		else
			echo "${php_name/.tar*/}安装失败！退出"
			exit 1
		fi
	else
		echo "${php_name/.tar*/}安装失败！"
		exit 1
	fi
	if [ -d "${appdir}php/" ];then
                rm -f ${appdir}php
                ln -s ${appdir}${php_name/.tar*/} ${appdir}php
        else
                ln -s ${appdir}${php_name/.tar*/} ${appdir}php
        fi
	cp php.ini-production ${appdir}php/lib/php.ini
	cp /application/php/etc/php-fpm.conf.default /application/php/etc/php-fpm.conf
	cp sapi/fpm/init.d.php-fpm /etc/rc.d/init.d/php-fpm
	chmod +x /etc/rc.d/init.d/php-fpm
	chkconfig --add php-fpm
	chkconfig php-fpm on
	cd ..
	rm -fr ${php_name/.tar*/}
else
	echo "${php_name/.tar*/}已安装！"
fi
	xcache_install
}
########xcache install
xcache_install(){
if [ `find ${appdir}php/ -type f -name "xcache.so"|wc -l` -eq 0 ];then
	wget -c $xcache_download &&echo "${xcache_name/.tar*/}安装包下载完成！"
	tar xf $xcache_name
	cd ${xcache_name/.tar*/}
	${appdir}php/bin/phpize
	./configure --enable-xcache --with-php-config=${appdir}php/bin/php-config
	if [ $? -eq 0 ];then
		make -j $cpu_num &&make install
		if [ $? -eq 0 ];then
			echo "${xcache_name/.tar*/}安装完成！"
		else
			echo "${xcache_name/.tar*/}安装失败！退出"
			exit 5
		if
	else
		echo "${xcache_name/.tar*/}安装失败！退出"
	fi
	cat xcache.ini >> ${appdir}php/lib/php.ini
	sed -ri 's#(xcache.size  = +)60M#\1256M#' ${appdir}php/lib/php.ini
	sed -ri 's#(xcache.count = +)1#\12#' ${appdir}php/lib/php.ini
	sed -ri 's#(xcache.ttl   = +)0#\186400#' ${appdir}php/lib/php.ini
	sed -ri 's#(xcache.gc_interval = +)0#\13600#' ${appdir}php/lib/php.ini
	sed -ri 's#(xcache.var_size  = +)4M#\164M#' ${appdir}php/lib/php.ini
else
	echo "xcache已安装！"
fi
	lnmp_start
}
########lnmp start
lnmp_start(){
cat > $appdir/nginx/html/test.php << EOF
<?php
//\$link_id=mysql_connect('主机名','用户','密码');
//mysql -u用户 -p密码 -h 主机
\$link_id=mysql_connect('localhost','','') or mysql_error();
        if(\$link_id){
                echo "mysql OK!\n";
        }else{
                echo mysql_error();
        }
        phpinfo();
?>
EOF
echo "php测试页：http://`hostname -I|awk '{print $1}'`.test.php"
nginx&&echo "Nginx启动成功"
service php-fpm restart&&echo "php启动成功"
service mysqld restart&&echo "mysql启动成功"
}
clear
echo -en "\033[;32m"
cat <<EOF
#########################################
#		  一键安装lnmpx 	#
#		作者：Areturn		#
#		QQ:2432556863		#
#########################################
EOF
read -p "确认安装请回车：" count
echo -en "\033[;0m"
[ -z $count ]&&Nginx_install||exit
