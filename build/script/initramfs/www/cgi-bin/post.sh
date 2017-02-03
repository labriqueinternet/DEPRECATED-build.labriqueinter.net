#!/bin/sh

read QUERY_STRING
passphrase=$(echo "${QUERY_STRING}" | sed 's/.*passphrase=\([^&]\+\).*/\1/')
echo -n $(httpd -d "${passphrase}") > /lib/cryptsetup/passfifo
sleep 5

echo -e "Content-type: text/plain\n"
status=unknown

while [ $status = unknown ]; do
  sleep 1

  if [ -b /dev/mapper/root ]; then
    status=success

  elif ps aux | grep -q [c]ryptsetup/askpass; then
    status=failed
  fi
done

echo -n $status

exit 0
