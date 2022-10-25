#!/bin/bash
cd /tmp
SITE_ROOT=/massbit/massbitroute/app/src/sites/services/mkagent
mkdir -p $SITE_ROOT
git clone --depth 1 -b shamu https://github.com/massbitprotocol/massbitroute_mkagent.git /massbit/massbitroute/app/src/sites/services/mkagent

mkdir -p $SITE_ROOT/vars
if [ -n "$MONITOR_TYPE" ]; then
	echo $MONITOR_TYPE >$SITE_ROOT/vars/TYPE
fi

if [ -n "$MONITOR_ID" ]; then
	echo $MONITOR_ID >$SITE_ROOT/vars/ID
fi

which supervisord
if [ $? -ne 0 ]; then
	apt update
	apt install -y supervisor
fi
cat >/etc/supervisor/conf.d/monitor_client.conf <<EOF
[program:monitor_client]
command=/massbit/massbitroute/app/src/sites/services/mkagent/agents/push.sh
autostart=true
EOF
supervisorctl update
