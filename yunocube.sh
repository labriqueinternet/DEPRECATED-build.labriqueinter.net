#!/bin/bash
set -e
set -x

InstallInternetCubeServices(){

# Install hypercube service
mkdir -p /var/log/hypercube
install -m 755 -o root -g root ${OVERLAY_PATH}/hypercube/hypercube.sh /usr/local/bin/
install -m 444 -o root -g root ${OVERLAY_PATH}/hypercube/hypercube.service /etc/systemd/system/
install -m 444 -o root -g root ${OVERLAY_PATH}/hypercube/install.html /var/log/hypercube/

# Enable hypercube service
# TODO use systemctl for doing this
ln -f -s '/etc/systemd/system/hypercube.service' /etc/systemd/system/multi-user.target.wants/hypercube.service

}

