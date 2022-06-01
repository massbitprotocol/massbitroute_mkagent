#!/bin/bash
_cache_f=/tmp/check_speed
cache=$1
if [ -z "$cache" ]; then cache=0; fi
# if [ $cache -ne 1 ]; then
if [ -f "$_cache_f" ]; then
	cat $_cache_f
	exit 0
fi

# fi

if [ ! -f "/usr/bin/speedtest-cli" ]; then
	apt install -y speedtest-cli
fi

speedtest-cli --simple | awk '{v[$1]=$2;l=l" "$0}END{for(i in v){i1=i;sub(/:$/,"",i1);l1=i1"="v[i]"|"l1};sub(/\|$/,"",l1);print "0 mbr_speed",l1,l}' >$_cache_f
cat $_cache_f
