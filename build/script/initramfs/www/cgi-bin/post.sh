#!/bin/sh

read QUERY_STRING
passphrase=$(echo "${QUERY_STRING}" | sed 's/.*passphrase=\([^&]\+\).*/\1/')
echo -n $(httpd -d "${passphrase}") > /lib/cryptsetup/passfifo

echo -e 'Content-type: text/plain\n'

for i in $(seq 75); do
  sleep 1

  if [ -f /dev/mapper/root ]; then
    echo success
    exit 0
  fi
done

echo failed

exit 0
