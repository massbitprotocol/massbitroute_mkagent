#!/bin/bash
sc=$(realpath $0)
dir=$(dirname $sc)
SITE_ROOT=$1
if [ -z "$SITE_ROOT" ]; then exit 0; fi

shift
# if [ "$SITE_ROOT" == "_kill" ]; then
# 	pkill -f push.py
# 	exit 0
# elif [ "$SITE_ROOT" == "_update_local_check" ]; then
# 	_update_local_check
# 	exit 0
# fi

source $SITE_ROOT/.env_raw
export PORTAL_DOMAIN=portal.$DOMAIN

cd $dir
if [ ! -f "/usr/bin/parallel" ]; then apt install -y parallel; fi

_update_local_check() {
	while true; do
		find $dir/local -type f -iname '*.sh' | while read cmd; do
			bash $cmd 1
		done
		sleep 30
	done
}
_push() {
	tmp=$(mktemp)
	curl -ksSfL https://$PORTAL_DOMAIN/deploy/info/hosts -o $tmp >/dev/nul
	echo >>$tmp
	while read _ip _host; do
		if [ -z "$_ip" ]; then continue; fi
		echo $_ip $_host
		grep $_host /etc/hosts >/dev/null
		if [ $? -ne 0 ]; then
			echo $_ip $_host >>/etc/hosts
		fi
	done <$tmp
	rm $tmp
	# export CHECK_MK_AGENT=$dir/check_mk_agent.linux
	export CHECK_MK_AGENT=$dir/check_mk_caching_agent.linux

	# ok1 export MK_SKIP_PS=true

	TYPE=$(cat $SITE_ROOT/vars/TYPE)
	if [ ! -f "$SITE_ROOT/vars/ID" ]; then
		echo 1 >$SITE_ROOT/vars/ID
	fi

	ID=$(cat $SITE_ROOT/vars/ID)
	TK="${TYPE}-${ID}"
	if [ \( "$TYPE" = "gateway" \) -o \( "$TYPE" = "node" \) ]; then
		export BLOCKCHAIN=$(cat $SITE_ROOT/vars/BLOCKCHAIN)
		export NETWORK=$(cat $SITE_ROOT/vars/NETWORK)
		export URL=https://${TYPE}-${BLOCKCHAIN}-${NETWORK}.monitor.mbr.$DOMAIN
		TK="${TYPE}-${BLOCKCHAIN}-${NETWORK}-${ID}"
	else
		TK="${HOSTNAME}"
		export URL=https://internal.monitor.mbr.$DOMAIN
	fi
	export TOKEN=$(echo -n ${TK} | sha1sum | cut -d' ' -f1)

	export PUSH_URL=push
	/usr/bin/python3 push.py
}
if [ $# -eq 0 ]; then
	(
		echo "$sc $SITE_ROOT _push"
		echo "$sc $SITE_ROOT _update_local_check"
	) | parallel -j2
else
	$@
fi
# if [ $# -le 2 ]; then
# 	# $pip --upgrade pip
# 	$pip -r requirements.txt
# 	python3 push.py
# else
# 	$@
# fi
