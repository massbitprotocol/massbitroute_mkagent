#!/bin/bash
nginx="$(ps -ef | awk '/nginx: master process/ {gsub(/^.*nginx: master process/,"");print}' | grep -v print | head -1)"
if [ -z "$nginx" ]; then
	echo $st nginx_check - "nginx process not found"
	exit 1
fi

msg="$($nginx -t 2>&1 | tail -1)"
st=$?
echo $st nginx_check - "$msg"
