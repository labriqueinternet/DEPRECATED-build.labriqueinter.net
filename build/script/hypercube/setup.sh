#!/bin/bash

# (test purposes)

set -x

mkdir -p /var/log/hypercube/

mv ./install.hypercube.example /root/install.hypercube
mv ./hypercube.service /etc/systemd/system/
mv ./hypercube*.sh /usr/local/bin/
mv ./install.html /var/log/hypercube/

chmod +x /usr/local/bin/hypercube*.sh

systemctl enable hypercube
systemctl start hypercube &
journalctl -fu hypercube

exit 0
