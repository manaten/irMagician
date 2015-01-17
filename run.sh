#!/bin/sh

PATH=/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

EXPRESS_STATIC='./public'
PORT="9090"
HUBOT_HTTPD="true"

case $1 in
    "start" | "stop" | "restart" )
       ./node_modules/forever/bin/forever $1 \
           --pidfile /var/run/irmagician.pid \
           -l /var/log/irmagician.log -a \
           -c ./node_modules/coffee-script/bin/coffee node_modules/hubot/bin/hubot
    ;;
    * ) echo "usage: run.sh start|stop|restart" ;;
esac
