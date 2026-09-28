#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
RECOVER_AT='/tmp/campus-off.recover-at'

[ -s "$RECOVER_AT" ] || exit 0

DEADLINE="$(cat "$RECOVER_AT")"
case "$DEADLINE" in
    ''|*[!0-9]*) logger -t campus-off 'Invalid recovery time'; exit 1 ;;
esac

[ "$(date +%s)" -ge "$DEADLINE" ] || exit 0

if ifstatus wan | grep -q '"up": true'; then
    rm -f "$RECOVER_AT"
    logger -t campus-off 'WAN recovery complete'
else
    logger -t campus-off 'One-hour timer reached; starting WAN'
    /sbin/ifup wan
fi
