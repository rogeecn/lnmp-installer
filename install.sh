#!/bin/bash
set -e

INSTALLER=/opt/lnmp

echo "goto directory /opt/lnmp"
mkdir -p $INSTALLER
cd $INSTALLER

echo "install PATH"
echo "export PATH=\$PATH:/usr/local/bin:/usr/local/php/73/sbin:/usr/local/php/73/bin:/usr/local/openresty/bin" >> ~/.bashrc
source ~/.bashrc

echo "alloc swap"
#fallocate -l 4G /swapfile
dd if=/dev/zero of=/swapfile bs=1024 count=2048000
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile   swap    swap    sw  0   0" >> /etc/fstab


echo "install epel"
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

echo "yum update..."
yum update -y

echo "install dev softwares..."
yum install -y expect git libxml2-devel bzip2-devel openssl openssl-devel curl-devel libjpeg-devel libpng-devel freetype-devel libxslt-devel libzip-devel gcc gcc-c++

echo "remove old libzip..."
yum remove libzip -y

echo "unzip packages: cmake..."
tar zxf $INSTALLER/packages/cmake-3.15.0.tar.gz -C src/

echo "unzip packages: libzip..."
tar zxf $INSTALLER/packages/libzip-1.5.2.tar.gz -C src/

echo "unzip packages: openresty..."
tar zxf $INSTALLER/packages/openresty-1.15.8.1.tar.gz -C src/

echo "unzip packages: php..."
tar zxf $INSTALLER/packages/php-7.3.8.tar.gz -C src/

echo "install cmake..."
cd $INSTALLER/src/cmake-3.15.0 && ./bootstrap && make && sudo make install

echo "install libzip..."
cd $INSTALLER/src/libzip-1.5.2
mkdir build
cd build
cmake ..
make
make test
make install

echo "add user: www-data"
groupadd www-data
useradd www-data -g www-data -s /sbin/nologin -M

echo "install openresty..."
cd $INSTALLER/src/openresty-1.15.8.1
./configure --prefix=/usr/local/openresty --user=www-data --group=www-data
gmake && gmake install
cp $INSTALLER/packages/nginx.service /usr/lib/systemd/system/nginx.service
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

echo "install php..."
cd $INSTALLER/src/php-7.3.8
./configure --prefix=/usr/local/php/73 --with-fpm-user=www-data --with-fpm-group=www-data --with-curl --with-freetype-dir --with-gd --with-gettext --with-iconv-dir --with-kerberos --with-libdir=lib64 --with-libxml-dir --with-mysqli --with-openssl --with-pcre-regex --with-pdo-mysql --with-pdo-sqlite --with-pear --with-png-dir --with-jpeg-dir --with-xmlrpc --with-xsl --with-zlib --with-bz2 --with-mhash --enable-fpm --enable-bcmath --enable-libxml --enable-inline-optimization --enable-mbregex --enable-mbstring --enable-opcache --enable-pcntl --enable-shmop --enable-soap --enable-sockets --enable-sysvsem --enable-sysvshm --enable-xml --enable-zip --enable-fpm
make && make install
cp $INSTALLER/packages/php.ini /usr/local/php/73/lib/php.ini
cp $INSTALLER/packages/www.conf /usr/local/php/73/etc/php-fpm.d/www.conf
cp $INSTALLER/packages/php-fpm.conf /usr/local/php/73/etc/php-fpm.conf
cp $INSTALLER/packages/php-fpm.service /usr/lib/systemd/system/php-fpm.service
systemctl daemon-reload
systemctl enable php-fpm
systemctl start php-fpm

echo "install composer"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'a5c698ffe4b8e849a443b120cd5ba38043260d5c4023dbf93e1558871f1f07f58274fc6f4c93bcfd858c6bd0775cd8d1') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"
chmod +x /usr/local/bin/composer


echo "install mariadb..."
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
yum update -y
yum install -y mariadb-server mariadb-client
mkdir -p /var/run/mariadb
chown mysql:mysql /var/run/mariadb
cp $INSTALLER/packages/server.cnf /etc/my.cnf.d/server.cnf
systemctl enable mysql
systemctl start mysql

echo "run mysql_secure_installation "
mysql_secure_installation <<EOF

y
secret
secret
y
y
y
y
EOF

systemctl restart mysql


echo "RUN checking.."
php -v
systemctl status php-fpm
systemctl status nginx
systemctl status mysql
composer --help