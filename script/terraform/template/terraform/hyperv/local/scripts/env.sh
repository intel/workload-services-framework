#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

cat <<EOF
{
  "http_proxy": "$http_proxy",
  "https_proxy": "$https_proxy",
  "no_proxy": "$no_proxy",
  "date_time_iso8601": "$(date -Ins)",
  "date_time_rfc3339": "$(date --rfc-3339=ns)",
  "time_zone": "$(timedatectl show --va -p Timezone 2> /dev/null || echo $TZ)"
}
EOF

