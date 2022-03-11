#!/bin/bash
# type=monitor
SITE_ROOT=$1
# if [ -z "$SITE_ROOT" ]; then
# 	SITE_ROOT=/massbit/massbitroute/app/src/sites/services/$type
# fi

# dir=$SITE_ROOT/etc/mkagent/agents
dir=$(dirname $(realpath $0))
pip="pip install "
cd $dir

if [ ! -f "/usr/bin/python3" ]; then
	apt install -y python3
fi

if [ ! -f "/usr/bin/pip" ]; then
	apt install -y python3-pip
fi

export URL=https://monitor.mbr.massbitroute.com
export CHECK_MK_AGENT=$dir/check_mk_agent.linux
# ok1 export MK_SKIP_PS=true

_kill() {
	kill $(ps -ef | grep -v grep | grep -i push.py | awk '{print $2}')
}
case $1 in
_kill)
	$@
	;;
*)
	TYPE=$(cat $SITE_ROOT/vars/TYPE)
	ID=$(cat $SITE_ROOT/vars/ID)
	TK="${TYPE}-${ID}"
	if [ \( "$TYPE" = "gateway" \) -o \( "$TYPE" = "node" \) ]; then
		BLOCKCHAIN=$(cat $SITE_ROOT/vars/BLOCKCHAIN)
		NETWORK=$(cat $SITE_ROOT/vars/NETWORK)
		TK="${TYPE}-${BLOCKCHAIN}-${NETWORK}-${ID}"
	fi
	export TOKEN=$(echo -n ${TK} | sha1sum | cut -d' ' -f1)

	$pip -r requirements.txt
	python3 $dir/push.py
	;;

esac

# if [ $# -le 2 ]; then
# 	# $pip --upgrade pip
# 	$pip -r requirements.txt
# 	python3 push.py
# else
# 	$@
# fi
