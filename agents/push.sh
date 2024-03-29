#!/bin/bash
sc=$(realpath $0)
dir=$(dirname $sc)
SITE_ROOT=$1
if [ -z "$SITE_ROOT" ]; then
	SITE_ROOT=$(realpath $dir/..)
else
	shift
fi

mkdir -p $SITE_ROOT/vars
if [ -n "$MONITOR_TYPE" ]; then
	echo $MONITOR_TYPE >$SITE_ROOT/vars/TYPE
fi

if [ -n "$MONITOR_ID" ]; then
	echo $MONITOR_ID >$SITE_ROOT/vars/ID
fi

if [ "$SITE_ROOT" == "_kill" ]; then
	pkill -f push.py
	exit 0
fi

if [ -f "$SITE_ROOT/env/env.sh" ]; then
	source $SITE_ROOT/env/env.sh
fi

if [ -f "$SITE_ROOT/data/env/env.sh" ]; then
	source $SITE_ROOT/data/env/env.sh
fi

# export PORTAL_DOMAIN=portal.$DOMAIN

cd $dir
which parallel
if [ $? -ne 0 ]; then
	apt update
	apt install -y parallel
fi
which pip3
if [ $? -ne 0 ]; then
	apt update
	apt install -y python3-pip
fi
pip3 install -r $SITE_ROOT/agents/requirements.txt

# if [ ! -f "/usr/bin/parallel" ]; then
# 	apt update
# 	apt install -y parallel
# fi
log_local_check=$SITE_ROOT/logs/local_check.log
log_push=$SITE_ROOT/logs/monitor_push.log
mkdir -p /massbit/massbitroute/app/src/sites/services/mkagent/agents
state_dir=/massbit/massbitroute/app/src/sites/services/mkagent/agents/state
if [ -d "$state_dir" ]; then
	rm -rf $state_dir
fi

if [ -z "$DOMAIN" ]; then
	echo "DOMAIN not set"
	exit 1
fi

if [ -z "$MONITOR_SCHEME" ]; then
	echo "MONITOR_SCHEME not set"
	exit 1
fi

export CHECK_MK_AGENT=$dir/check_mk_agent.linux

TYPE=$(cat $SITE_ROOT/vars/TYPE)
if [ ! -f "$SITE_ROOT/vars/ID" ]; then
	echo 1 >$SITE_ROOT/vars/ID
fi

ID=$(cat $SITE_ROOT/vars/ID)
if [ -z "$ID" ]; then exit 1; fi

export URL=$MONITOR_SCHEME://internal.monitor.mbr.$DOMAIN
if [ \( "$TYPE" = "gateway" \) -o \( "$TYPE" = "node" \) ]; then
	export BLOCKCHAIN=$(cat $SITE_ROOT/vars/BLOCKCHAIN)
	export NETWORK=$(cat $SITE_ROOT/vars/NETWORK)
	export URL=$MONITOR_SCHEME://${TYPE}-${BLOCKCHAIN}-${NETWORK}.monitor.mbr.$DOMAIN
	TK="${TYPE}-${BLOCKCHAIN}-${NETWORK}-${ID}"
elif [ "$TYPE" = "monitor" ]; then
	export MON_TYPE=$(cat $SITE_ROOT/vars/MONITOR_TYPES)
	export MON_BLOCK=$(cat $SITE_ROOT/vars/MONITOR_BLOCKCHAINS)
	export MON_NET=$(cat $SITE_ROOT/vars/MONITOR_NETWORKS)

	TK="${TYPE}-${MON_TYPE}-${MON_BLOCK}-${MON_NET}-${ID}"
elif [ "$TYPE" = "stat" ]; then
	export MON_TYPE=$(cat $SITE_ROOT/vars/STAT_TYPE)
	export MON_BLOCK=$(cat $SITE_ROOT/vars/STAT_BLOCKCHAIN)
	export MON_NET=$(cat $SITE_ROOT/vars/STAT_NETWORK)
	TK="${TYPE}-${MON_TYPE}-${MON_BLOCK}-${MON_NET}-${ID}"
elif [ "$TYPE" = "explorer" ]; then
	export MON_TYPE=$(cat $SITE_ROOT/vars/EXPLORER_TYPE)
	export MON_BLOCK=$(cat $SITE_ROOT/vars/EXPLORER_BLOCKCHAIN)
	export MON_NET=$(cat $SITE_ROOT/vars/EXPLORER_NETWORK)
	TK="${TYPE}-${MON_TYPE}-${MON_BLOCK}-${MON_NET}-${ID}"
else
	if [ -z "$ID" ]; then
		ID=$HOSTNAME
	fi

	TK="${TYPE}-${ID}"
fi
export TOKEN=$(echo -n ${TK} | sha1sum | cut -d' ' -f1)

export PUSH_URL=push

echo $TOKEN $TK
loop() {
	while true; do
		$0 $SITE_ROOT $@
		sleep 30
	done

}
_update_local_check() {

	# while true; do
	echo "$date" >>$log_local_check
	_t1=$(date +%s)
	find $dir/local -type f -iname '*.sh' | while read cmd; do
		echo bash $cmd 1 >>$log_local_check
		timeout 300 bash $cmd 1 >>$log_local_check
	done
	_t2=$(date +%s)
	_t=$(expr $_t2 - $_t1)
	echo "0 local_check_time t=$_t time run $_t seconds" >$state_dir
	# 	sleep 30
	# done
}
_push() {

	# while true; do

	/usr/bin/python3 push.py >>$log_push
	# 	sleep 30
	# done

}
if [ $# -eq 0 ]; then
	(
		echo "$sc $SITE_ROOT loop _push"
		echo "$sc $SITE_ROOT loop _update_local_check"
	) | parallel -j2
else
	$@
fi
