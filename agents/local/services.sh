#!/bin/bash
type=$(supervisorctl status | awk '/mbr_(gateway|node) /{sub(/^mbr_/,"",$1);print $1}')
if [ \( "$type" != "node" \) -a \( "$type" != "gateway" \) ]; then
	exit 0
fi
# cmd=/massbit/massbitroute/app/src/sites/services/$type/cmd_server
# if [ ! -x "$cmd" ]; then exit 0; fi
# nginx="$(ps -ef | awk '/nginx: master process/ {gsub(/^.*nginx: master process/,"");gsub(/nginx.conf.*$/,"nginx.conf");print}' | grep -v awk | head -1)"
# if [ -z "$nginx" ]; then
# 	echo $st nginx_check - "nginx process not found"
# 	exit 1
# fi

nginx="/massbit/massbitroute/app/src/sites/services/$type/bin/openresty/nginx/sbin/nginx -c /massbit/massbitroute/app/src/sites/services/$type/tmp/nginx.conf"
msg="$($nginx -t 2>&1 | tr -s '\n' ' ')"
st=$?
echo $st nginx_check - "$msg"
