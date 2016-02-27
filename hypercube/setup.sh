#!/bin/bash

# (test purposes)

set -x

mv ./install.hypercube.example /root/install.hypercube
mv ./hypercube.service /etc/systemd/system/
mv ./hypercube*.sh /usr/local/bin/

chmod +x /usr/local/bin/hypercube*.sh

systemctl enable hypercube

journalctl -fu hypercube
#systemctl start hypercube

exit 0
