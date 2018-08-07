#! /bin/bash

source /home/ubuntu/tsugi_env.sh

if [ -z "$MYSQL_ROOT_PASSWORD" ] ; then
   echo Must set MYSQL_ROOT_PASSWORD
   exit
fi

if [ -z "$DEV_SERVER_LIST" ] ; then
   echo Must set DEV_SERVER_LIST
   exit
fi

echo "Emptying /var/www/html/d"
rm -rf /var/www/html/d
mkdir /var/www/html/d

echo Downloading phpMyAdmin
cd /home/ubuntu
curl -O https://files.phpmyadmin.net/phpMyAdmin/4.7.9/phpMyAdmin-4.7.9-all-languages.zip


for i in $DEV_SERVER_LIST; do
  host=`echo $i | awk -F',' '{print $1}'`
  admin=`echo $i | awk -F',' '{print $2}'`
  dbpw=pw_$(($RANDOM+$RANDOM*$RANDOM))
  dbpw=db_$admin
  echo
  echo ===== Processing $host
  echo Host $host $admin $dbpw

mysql -u root --password=$MYSQL_ROOT_PASSWORD << EOF
DROP DATABASE $host
EOF

mysql -u root --password=$MYSQL_ROOT_PASSWORD << EOF
    CREATE DATABASE $host DEFAULT CHARACTER SET utf8;
    GRANT ALL ON $host.* TO '$host'@'localhost' IDENTIFIED BY '$dbpw';
    GRANT ALL ON $host.* TO '$host'@'127.0.0.1' IDENTIFIED BY '$dbpw';
EOF

echo Creating web for $host
git clone https://github.com/tsugicloud/dev-jekyll-site.git /var/www/html/d/$host

echo Creating tsugi for $host
git clone https://github.com/tsugiproject/tsugi /var/www/html/d/$host/tsugi

echo Adding a few tools for $host
cd /var/www/html/d/$host/tsugi/mod
git clone https://github.com/tsugitools/youtube.git
git clone https://github.com/tsugitools/map.git

echo Configuring tsugi for $host
export TSUGI_USER=$host
export TSUGI_PASSWORD=$dbpw
export TSUGI_PDO="mysql:host=localhost;dbname=$host"
export TSUGI_ADMINPW=$admin
export TSUGI_MAILDOMAIN=tsugicloud.org
export TSUGI_APPHOME=https://dev.tsugicloud.org/d/$host
export TSUGI_WWWROOT=https://dev.tsugicloud.org/d/$host/tsugi

php /home/ubuntu/ami-sql/fixconfig.php < /home/ubuntu/ami-sql/config.php > /var/www/html/d/$host/tsugi/config.php

echo Setting up database for $host
cd /var/www/html/d/$host/tsugi/admin
php upgrade.php

echo Setting up phpMyAdmin for $host

cd /home/ubuntu
X=`sha256sum phpMyAdmin-4.7.9-all-languages.zip | awk '{print $1}'`
if [ "$X" == "2fb9f7b31ae7cb71f6398e5da8349fb4f41339386e06a851c4444fc7a938a38a" ]
then
  echo "Sha Match"
  rm -rf phpMyAdmin-4.7.9-all-languages
  unzip phpMyAdmin-4.7.9-all-languages.zip
  mv phpMyAdmin-4.7.9-all-languages /var/www/html/d/$host/phpMyAdmin
else
  echo "SHA256 mismatch"
fi

done

echo "Resetting permissions on /var/www/html"
chown -R www-data:www-data /var/www/html

