#!/bin/bash
_type=$(supervisorctl status | awk '$1 !~ /_monitor/ && $1 ~ /^mbr_/{gsub(/^mbr_/,"",$1);print $1}')
_cmd=/massbit/massbitroute/app/src/sites/services/${_type}/cmd_server

if [ ! -f "$_cmd" ]; then exit 0; fi

tmp=$(mktemp)
$_cmd status | awk '$3 ~ /pid/' >$tmp
n=$(wc -l $tmp | cut -d' ' -f1)
grep -v RUNNING $tmp >${tmp}.1
st=0
if [ $? -ne 0 ]; then
	st=2
fi
echo "$st mbr-cmd_server - n=$n $(cat ${tmp}.1)"
rm $tmp*
