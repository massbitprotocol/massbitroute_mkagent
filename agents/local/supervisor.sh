#!/bin/bash
exit 0
tmp=$(mktemp)
supervisorctl status >$tmp
n=$(wc -l $tmp | cut -d' ' -f1)
grep -v RUNNING $tmp >${tmp}.1
st=0
if [ $? -ne 0 ]; then
	st=2
fi
echo "$st mbr-supervisor - n=$n $(cat ${tmp}.1)"
rm $tmp*
