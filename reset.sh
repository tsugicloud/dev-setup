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

save_apphome=$TSUGI_APPHOME

echo "Emptying /var/www/html/dev"
rm -rf /var/www/html/dev
rm /var/www/html/index.html
rm /var/www/html/.htaccess

echo Downloading phpMyAdmin
cd /home/ubuntu
curl -O https://files.phpmyadmin.net/phpMyAdmin/4.7.9/phpMyAdmin-4.7.9-all-languages.zip

# Start the main page
cat << EOF > /var/www/html/index.php
<html>
<head>
</head>
<body>
<h1>Welcome to the Tsugi Developer Sites</h1>
<p>You can test your Tsugi tools and Tsugi skills on the server(s) in the list below.
</p>
<ul>
EOF

for i in $DEV_SERVER_LIST; do
  host=`echo $i | awk -F',' '{print $1}'`
  admin=`echo $i | awk -F',' '{print $2}'`
  dbpw=pw_$(($RANDOM+$RANDOM*$RANDOM))
  dbpw=db_$admin
  echo
  echo ===== Processing $host
  echo Host $host $admin $dbpw
  url=https://$host.$TSUGI_MAILDOMAIN
  echo "<li><p><a href=\"$url\" target=\"_blank\">$url</a></p></li>" >> /var/www/html/index.php

echo "Setting up virtual hosting"
rm /etc/apache2/sites-available/$host.$TSUGI_MAILDOMAIN
rm /etc/apache2/sites-enabled/$host.$TSUGI_MAILDOMAIN

cat << EOF > /etc/apache2/sites-available/$host.$TSUGI_MAILDOMAIN.conf
<VirtualHost *:80>
    # The ServerName directive sets the request scheme, hostname and port that
    # the server uses to identify itself. This is used when creating
    # redirection URLs. In the context of virtual hosts, the ServerName
    # specifies what hostname must appear in the request's Host: header to
    # match this virtual host. For the default virtual host (this file) this
    # value is not decisive as it is used as a last resort host regardless.
    # However, you must set it for any further virtual host explicitly.
    #ServerName www.example.com

        ServerName $host.$TSUGI_MAILDOMAIN
    ServerAdmin $TSUGI_OWNEREMAIL
    DocumentRoot /var/www/html/dev/$host

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
    # after it has been globally disabled with "a2disconf".
    #Include conf-available/serve-cgi-bin.conf
</VirtualHost>

<Directory /var/www/html/dev/$host>
                Options Indexes FollowSymLinks
                AllowOverride All
                Order allow,deny
                allow from all
</Directory>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF

cd /etc/apache2/sites-enabled
rm $host.$TSUGI_MAILDOMAIN
ln -s ../sites-available/$host.$TSUGI_MAILDOMAIN.conf


mysql -u root --password=$MYSQL_ROOT_PASSWORD << EOF
DROP DATABASE $host
EOF

mysql -u root --password=$MYSQL_ROOT_PASSWORD << EOF
    CREATE DATABASE $host DEFAULT CHARACTER SET utf8;
    GRANT ALL ON $host.* TO '$host'@'localhost' IDENTIFIED BY '$dbpw';
    GRANT ALL ON $host.* TO '$host'@'127.0.0.1' IDENTIFIED BY '$dbpw';
EOF

echo Creating web for $host
git clone https://github.com/tsugicloud/dev-jekyll-site.git /var/www/html/dev/$host

echo Creating tsugi for $host
git clone https://github.com/tsugiproject/tsugi /var/www/html/dev/$host/tsugi

echo Adding a few tools for $host
cd /var/www/html/dev/$host/mod
pwd
git clone https://github.com/tsugitools/youtube.git
git clone https://github.com/tsugitools/map.git
git clone https://github.com/tsugicontrib/lmstest.git

echo Configuring tsugi for $host
export TSUGI_USER=$host
export TSUGI_PASSWORD=$dbpw
export TSUGI_PDO="mysql:host=localhost;dbname=$host"
export TSUGI_ADMINPW=$admin
export TSUGI_APPHOME=https://$host.$TSUGI_MAILDOMAIN
export TSUGI_WWWROOT=https://$host.$TSUGI_MAILDOMAIN/tsugi

php /home/ubuntu/ami-sql/fixconfig.php < /home/ubuntu/ami-sql/config.php > /var/www/html/dev/$host/tsugi/config.php

echo Setting up database for $host
cd /var/www/html/dev/$host/tsugi/admin
php upgrade.php

echo Setting up phpMyAdmin for $host

cd /home/ubuntu
X=`sha256sum phpMyAdmin-4.7.9-all-languages.zip | awk '{print $1}'`
if [ "$X" == "2fb9f7b31ae7cb71f6398e5da8349fb4f41339386e06a851c4444fc7a938a38a" ]
then
  echo "Sha Match"
  rm -rf phpMyAdmin-4.7.9-all-languages
  unzip phpMyAdmin-4.7.9-all-languages.zip
  mv phpMyAdmin-4.7.9-all-languages /var/www/html/dev/$host/phpMyAdmin
else
  echo "SHA256 mismatch"
fi

done

# Finish the main page
last_reset=`date`
cat << EOF >> /var/www/html/index.php
</ul>
<p>
These servers are completely emptied out and rebuilt
every few days so don't count on them.
</p>
<p>
Most recent reset: $last_reset
</p>
</body>
</html>
EOF

echo "Resetting permissions on /var/www/html"
chown -R www-data:www-data /var/www/html

apachectl restart
