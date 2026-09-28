#!/bin/sh

TOPIC="$(cat /etc/campus-off.topic 2>/dev/null)"
CURSOR='/etc/campus-off.cursor'
RECOVER_AT='/tmp/campus-off.recover-at'

[ -n "$TOPIC" ] || exit 1

if [ ! -s "$CURSOR" ]; then
    date +%s > "$CURSOR"
fi

while :; do
    if ! ifstatus wan | grep -q '"up": true'; then
        sleep 10
        continue
    fi

    SINCE="$(cat "$CURSOR")"
    curl -fsSN --connect-timeout 10 --max-time 3600 \
        "https://ntfy.sh/$TOPIC/json?since=$SINCE" 2>/dev/null |
    while IFS= read -r LINE; do
        EVENT="$(jsonfilter -s "$LINE" -e '@.event' 2>/dev/null)"
        [ "$EVENT" = 'message' ] || continue

        ID="$(jsonfilter -s "$LINE" -e '@.id' 2>/dev/null)"
        MESSAGE="$(jsonfilter -s "$LINE" -e '@.message' 2>/dev/null)"
        [ -n "$ID" ] && printf '%s\n' "$ID" > "$CURSOR"

        if [ "$MESSAGE" = 'OFF' ]; then
            NOW="$(date +%s)"
            printf '%s\n' "$((NOW + 3600))" > "$RECOVER_AT"
            logger -t campus-off 'Remote WAN disconnect requested; recovery scheduled in 1 hour'
            /sbin/ifdown wan
            exit 0
        fi
    done

    sleep 5
done
