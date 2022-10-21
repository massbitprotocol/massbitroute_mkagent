#!/bin/bash
sc=$(realpath $0)
dir=$(dirname $sc)
SITE_ROOT=$1
if [ -z "$SITE_ROOT" ]; then exit 0; fi

shift
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
if [ ! -f "/usr/bin/parallel" ]; then apt install -y parallel; fi
log_local_check=$SITE_ROOT/logs/local_check.log
log_push=$SITE_ROOT/logs/monitor_push.log
mkdir -p /massbit/massbitroute/app/src/sites/services/mkagent/agents
state_dir=/massbit/massbitroute/app/src/sites/services/mkagent/agents/state
if [ -d "$state_dir" ]; then
	rm -rf $state_dir
fi

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

	if [ \( "$TYPE" = "gateway" \) -o \( "$TYPE" = "node" \) ]; then
		export BLOCKCHAIN=$(cat $SITE_ROOT/vars/BLOCKCHAIN)
		export NETWORK=$(cat $SITE_ROOT/vars/NETWORK)
		export URL=$MONITOR_SCHEME://${TYPE}-${BLOCKCHAIN}-${NETWORK}.monitor.mbr.$DOMAIN
		TK="${TYPE}-${BLOCKCHAIN}-${NETWORK}-${ID}"
	else
		if [ -z "$ID" ]; then
			ID=$HOSTNAME
		fi

		TK="${TYPE}-${ID}"
		export URL=$MONITOR_SCHEME://internal.monitor.mbr.$DOMAIN
	fi
	export TOKEN=$(echo -n ${TK} | sha1sum | cut -d' ' -f1)

	export PUSH_URL=push
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
