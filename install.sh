#!/bin/bash
cd /tmp
git clone --depth 1 -b shamu https://github.com/massbitprotocol/massbitroute_mkagent.git /massbit/massbitroute/app/src/sites/services/mkagent
/massbit/massbitroute/app/src/sites/services/mkagent/agents/push.sh
