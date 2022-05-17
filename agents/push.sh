#!/bin/bash

# type=monitor
SITE_ROOT=$1
if [ -z "$SITE_ROOT" ]; then exit 0; fi
if [ "$SITE_ROOT" == "_kill" ]; then
	pkill -f push.py
	exit 0
fi

if [ -f "$SITE_ROOT/.env_raw" ]; then source $SITE_ROOT/.env_raw; fi

# if [ -z "$SITE_ROOT" ]; then
# 	SITE_ROOT=/massbit/massbitroute/app/src/sites/services/$type
# fi

# dir=$SITE_ROOT/etc/mkagent/agents
dir=$(dirname $(realpath $0))
# pip="pip install "
cd $dir

# if [ ! -f "/usr/bin/python3" ]; then
# 	apt install -y python3
# fi

# if [ ! -f "/usr/bin/pip" ]; then
# 	apt install -y python3-pip
# fi

export PORTAL_DOMAIN=portal.$DOMAIN

tmp=$(mktemp)
curl -ksSfL https://$PORTAL_DOMAIN/deploy/hosts -o $tmp >/dev/nul
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
ID=$(cat $SITE_ROOT/vars/ID)
NETWORK=$(cat $SITE_ROOT/vars/NETWORK)
BLOCKCHAIN=$(cat $SITE_ROOT/vars/BLOCKCHAIN)
TK="${TYPE}-${ID}"
if [ \( "$TYPE" = "gateway" \) -o \( "$TYPE" = "node" \) ]; then

	export BLOCKCHAIN=$(cat $SITE_ROOT/vars/BLOCKCHAIN)
	export NETWORK=$(cat $SITE_ROOT/vars/NETWORK)
	export URL=https://${TYPE}-${BLOCKCHAIN}-${NETWORK}.monitor.mbr.$DOMAIN
	TK="${TYPE}-${BLOCKCHAIN}-${NETWORK}-${ID}"
fi
export TOKEN=$(echo -n ${TK} | sha1sum | cut -d' ' -f1)
#export PUSH_URL=push_${TYPE}_${BLOCKCHAIN}_${NETWORK}
export PUSH_URL=push

# if [ "$TYPE" = "gateway" ]; then
# 	export PUSH_URL=push_gw_${BLOCKCHAIN}_${NETWORK}
# fi
# $pip --upgrade pip
# $pip -r requirements.txt
python3 $dir/push.py

# if [ $# -le 2 ]; then
# 	# $pip --upgrade pip
# 	$pip -r requirements.txt
# 	python3 push.py
# else
# 	$@
# fi
