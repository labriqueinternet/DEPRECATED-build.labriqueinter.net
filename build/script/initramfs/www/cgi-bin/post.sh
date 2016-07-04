#!/bin/sh

read QUERY_STRING

# We now split the query string at '&' then each part at '='
# We look for the X in a=b&passphrase=X&c=d
passphrase_urlenc=$(echo "$QUERY_STRING" | awk -F'&'   \
  '{                                                   \
    for(i=1; i <= NF; i++) {                           \
      n = split($i, array, "=");                       \
      if(n == 2 && index(array[1], "passphrase")) {    \
        print array[2];                                \
        break;                                         \
      }                                                \
    }                                                  \
  }'                                                   \
)

echo -n $(httpd -d "$passphrase_urlenc") > /lib/cryptsetup/passfifo

for i in $(seq 30); do
  sleep 1

  if [ -f /dev/mapper/root ]; then
    cat ../index.html | sed '/TPL:UNLOCKED/d'
    exit 0
  fi
done

cat ../index.html | sed 's/caticorn/&_failed/' | sed '/TPL:ERROR/d'

exit 0
