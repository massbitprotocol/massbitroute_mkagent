#!/bin/bash
tmp=$(mktemp)
supervisorctl status >$tmp
n=$(wc -l $tmp | cut -d' ' -f1)
grep -v RUNNING $tmp >${tmp}.1
st=0
if [ $? -eq 0 ]; then
	st=2
fi
echo "$st mbr-supervisor $n $(cat ${tmp}.1)"
rm $tmp*
