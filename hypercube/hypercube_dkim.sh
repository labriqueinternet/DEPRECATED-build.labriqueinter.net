#!/bin/bash

# LaBriqueInternet HyperCube Installer (DKIM configuration)
# Copyright (C) 2016 Julien Vaubourg <julien@vaubourg.com>
# Contribute at https://github.com/labriqueinternet/build.labriqueinter.net
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e
set -x

domain=$1

if [ -z "${domain}" ]; then
  echo "Usage: $0 domain" >&2
  exit 1
fi

# Packages
apt-get install --no-install-recommends opendkim opendkim-tools -y --force-yes

# OpenDKIM
echo 'SOCKET=inet6:8891@localhost' > /etc/default/opendkim

cat << EOF > /etc/opendkim.conf
AutoRestart             yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           yes
LogWhy                  yes
Canonicalization        relaxed/simple
ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256
UserID                  opendkim:opendkim
Socket                  inet6:8891@localhost
Selector                mail
EOF

# Postfix
if grep -q '^milter_default_action\s*=' /etc/postfix/main.cf; then
  sed 's/^milter_default_action\s*=.*/milter_default_action = accept/' -i /etc/postfix/main.cf
else
  echo 'milter_default_action = accept' >> /etc/postfix/main.cf
fi

if grep -q '^milter_protocol\s*=' /etc/postfix/main.cf; then
  sed 's/^milter_protocol\s*=.*/milter_protocol = 2/' -i /etc/postfix/main.cf
else
  echo 'milter_protocol = 2' >> /etc/postfix/main.cf
fi

if grep -q '^smtpd_milters\s*=' /etc/postfix/main.cf; then
  sed 's/^smtpd_milters\s*=.*/&, inet6:localhost:8891/' -i /etc/postfix/main.cf
else
  echo 'smtpd_milters = inet6:localhost:8891' >> /etc/postfix/main.cf
fi

if grep -q '^non_smtpd_milters\s*=' /etc/postfix/main.cf; then
  sed 's/^non_smtpd_milters\s*=.*/&, inet6:localhost:8891/' -i /etc/postfix/main.cf
else
  echo 'non_smtpd_milters = inet6:localhost:8891' >> /etc/postfix/main.cf
fi

# Domain
mkdir -p "/etc/opendkim/keys/${domain}/"

cat << EOF > /etc/opendkim/TrustedHosts
::1
127.0.0.1

fe80::/10
fd00::/8
10.0.0.0/8
192.168.0.0/16
172.16.0.0/12

localhost
${domain}
*.${domain}
EOF

echo "mail._domainkey.${domain} ${domain}:mail:/etc/opendkim/keys/${domain}/mail.private" > /etc/opendkim/KeyTable
echo "*@${domain} mail._domainkey.${domain}" > /etc/opendkim/SigningTable

opendkim-genkey -s mail -d "${domain}" -D "/etc/opendkim/keys/${domain}/"
chown opendkim: "/etc/opendkim/keys/${domain}/mail.private"

systemctl enable opendkim

exit 0
