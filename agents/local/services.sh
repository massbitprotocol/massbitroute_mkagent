#!/bin/bash
nginx=$(ps -ef | awk '/nginx: master process/ {gsub(/^.*nginx: master process/,"");print}' | head -1)
msg=$($nginx -t 2>&1)
st=$?
echo $st nginx_check - $msg
