#!/bin/bash
exit 0
_dir=/massbit/massbitroute/app/src/sites/services/mkagent/agents/state
find $_dir -type f | while read f; do cat $f; done
