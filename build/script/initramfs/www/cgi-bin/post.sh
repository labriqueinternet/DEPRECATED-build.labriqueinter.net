#!/bin/sh

read QUERY_STRING
passphrase=$(echo "${QUERY_STRING}" | sed 's/.*passphrase=\([^&]\+\).*/\1/')
echo -n $(httpd -d "${passphrase}") > /lib/cryptsetup/passfifo

echo -e "Content-type: text/plain\n"
status=unknown

while [ $status = unknown ]; do
  if [ ! -f /bin/sleep ]; then
    status=success

  elif ps aux | grep -q [c]ryptsetup/askpass; then
    status=failed
  fi

  sleep 1
done

echo -n $status

exit 0
