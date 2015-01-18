#!/bin/sh

export EXPRESS_STATIC="./public"
export PORT="9090"
export HUBOT_HTTPD="true"
export HUBOT_SLACK_TOKEN=""

case $1 in
    "start" )
        ./node_modules/.bin/forever $1 \
            --pidfile /var/run/irmagician.pid \
            -l /var/log/irmagician.log -a \
            --uid "irmagician" \
            -c ./node_modules/.bin/coffee node_modules/.bin/hubot -a slack -n mana_bot
    ;;
    "stop" | "restart" )
        ./node_modules/.bin/forever $1 "irmagician"
    ;;
    * ) echo "usage: run.sh start|stop|restart" ;;
esac
