#!/bin/bash
#字体 颜色
Green="\033[32m" 
Red="\033[31m" 
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#信息颜色
Info="${Yellow}[Info]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[Error]${Font}"

#检查软件是否安装，通过dpkg -l，未安装则安装
check_software_installed_l(){
    if [[ 1 -le `dpkg -l | grep "$1" | wc -l` ]];then
        echo -e "${OK} ${GreenBG} $1 已经安装 ${Font}"
        sleep 1
    else
        echo -e "${info} ${Yellow} $1 未安装，现在安装 ${Font}"
        apt install $1
    fi
}

#检查软件是否安装，通过dpkg -s，未安装则安装
check_software_installed_s(){
    if [[ 1 -eq `dpkg -s $1 | grep "Status: install ok installed" | wc -l` ]];then
        echo -e "${OK} ${GreenBG} $1 已经安装 ${Font}"
        sleep 1
    else
        echo -e "${Info} ${Yellow} $1 未安装，现在安装 ${Font}"
        apt install $1 -y
    fi
}

php_install(){
    install_software_list=("-cli" "-curl")
    echo -e "${GreenBG} 开始安装PHP7 ${Font}"
    read -p "请输入你想要安装的php版本（默认$default_version）:" php_version

    if [ "$php_version" = "" ]; 
    then
        php_version=$default_version
    fi
	for item in ${install_software_list[@]}
	do
		check_software_installed_s $php_version$item
	done
}


check_webserver(){
    installed_server=" "
    if [[ 1 -eq `dpkg -s apache2 | grep "Status: install ok installed" | wc -l` ]];then
        echo -e "${OK} ${GreenBG} apache2 已经安装 ${Font}"
        apache2_sites
        sleep 1
    elif [[ 1 -eq `dpkg -s nginx | grep "Status: install ok installed" | wc -l` ]];then
        echo -e "${OK} ${GreenBG} nginx 已经安装 ${Font}"
        fpm="-fpm"
        check_software_installed_s $default_version$fpm
        nginx_sites
        sleep 1
    else 
        echo -e "${Info} ${Yellow} apache2和nginx均未安装，现在安装apache2 ${Font}"
		check_software_installed_s apache2
    fi
}

oneindex_install(){
    echo -e "${GreenBG} 开始安装oneindex ${Font}"
	cd /var/www/
    git clone https://github.com/donwa/oneindex.git
    chown -R www-data:www-data oneindex/
    chmod -R 755 oneindex/
}

###########################站点配置#####################
apache2_sites(){
    find_port 8080
    sed -i "/^Listen 80$/a\Listen $available_port" /etc/apache2/ports.conf
    echo "<VirtualHost *:$available_port>
	# The ServerName directive sets the request scheme, hostname and port that
	# the server uses to identify itself. This is used when creating
	# redirection URLs. In the context of virtual hosts, the ServerName
	# specifies what hostname must appear in the request's Host: header to
	# match this virtual host. For the default virtual host (this file) this
	# value is not decisive as it is used as a last resort host regardless.
	# However, you must set it for any further virtual host explicitly.
	#ServerName www.example.com

	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/oneindex

	# Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
	# error, crit, alert, emerg.
	# It is also possible to configure the loglevel for particular
	# modules, e.g.
	#LogLevel info ssl:warn

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

	# For most configuration files from conf-available/, which are
	# enabled or disabled at a global level, it is possible to
	# include a line for only one particular virtual host. For example the
	# following line enables the CGI configuration for this host only
	# after it has been globally disabled with \"a2disconf\".
	#Include conf-available/serve-cgi-bin.conf
</VirtualHost>
# vim: syntax=apache ts=4 sw=4 sts=4 sr noet" > /etc/apache2/sites-available/oneindex.conf
    ln -s /etc/apache2/sites-available/oneindex.conf /etc/apache2/sites-enabled/oneindex.conf
    /etc/init.d/apache2 restart
}

nginx_sites(){
    find_port 8080
    echo "##
# You should look at the following URL's in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# https://www.nginx.com/resources/wiki/start/
# https://www.nginx.com/resources/wiki/start/topics/tutorials/config_pitfalls/
# https://wiki.debian.org/Nginx/DirectoryStructure
#
# In most cases, administrators will remove this file from sites-enabled/ and
# leave it as reference inside of sites-available where it will continue to be
# updated by the nginx packaging team.
#
# This file will automatically load configuration files provided by other
# applications, such as Drupal or Wordpress. These applications will be made
# available underneath a path with that package name, such as /drupal8.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##

# Default server configuration
#
server {
	listen $available_port default_server;
	listen [::]:$available_port default_server;

	# SSL configuration
	#
	# listen 443 ssl default_server;
	# listen [::]:443 ssl default_server;
	#
	# Note: You should disable gzip for SSL traffic.
	# See: https://bugs.debian.org/773332
	#
	# Read up on ssl_ciphers to ensure a secure configuration.
	# See: https://bugs.debian.org/765782
	#
	# Self signed certs generated by the ssl-cert package
	# Don't use them in a production server!
	#
	# include snippets/snakeoil.conf;

	root /var/www/oneindex;

	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html index.php;

	server_name _;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files \$uri \$uri/ =404;
	}

	# pass PHP scripts to FastCGI server
	#
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
	
		# With php-fpm (or other unix sockets):
		fastcgi_pass unix:/run/php/$default_version-fpm.sock;
		# With php-cgi (or other tcp sockets):
		#fastcgi_pass 127.0.0.1:9000;
	}

	# deny access to .htaccess files, if Apache's document root
	# concurs with nginx's one
	#
	#location ~ /\.ht {
	#	deny all;
	#}
}


# Virtual Host configuration for example.com
#
# You can move that to a different file under sites-available/ and symlink that
# to sites-enabled/ to enable it.
#
#server {
#	listen 80;
#	listen [::]:80;
#
#	server_name example.com;
#
#	root /var/www/example.com;
#	index index.html;
#
#	location / {
#		try_files \$uri \$uri/ =404;
#	}
#}" > /etc/nginx/sites-available/oneindex
    ln -s /etc/nginx/sites-available/oneindex /etc/nginx/sites-enabled/oneindex
    service nginx restart
}
