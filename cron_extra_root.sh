#! /bin/bash

# x=`find /var/www/html/dev -maxdepth 0 -type d -mmin +6 | wc -l`

x=`find /var/www/html/dev -maxdepth 0 -type d -ctime +2 | wc -l`
echo $x
if [[ $x > 0  ]] ; then
  echo Doing the reset `date` > /tmp/reset-time.txt
  chown -R www-data:www-data /var/www/html
  bash /home/ubuntu/dev-setup/reset.sh
  chown -R www-data:www-data /var/www/html
fi

