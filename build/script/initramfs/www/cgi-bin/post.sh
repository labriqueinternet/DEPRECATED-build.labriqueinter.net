#!/bin/sh

read QUERY_STRING
eval $(echo "$QUERY_STRING" | awk -F'&' '{for(i=1; i <= NF; i++) { print $i }}')

echo -n $(httpd -d $passphrase) > /lib/cryptsetup/passfifo

for i in $(seq 20); do
  sleep 1

  if [ -f /dev/mapper/root ]; then
    cat ../index.html | sed '/TPL:UNLOCKED/d'
    exit 0
  fi
done

cat ../index.html | sed 's/caticorn/&_failed/' | sed '/TPL:ERROR/d'

exit 0
