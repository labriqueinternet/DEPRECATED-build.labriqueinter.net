#!/bin/bash

# LaBriqueInternet HyperCube Installer
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

##
## ntfs-3g?
##

set -e
set -x


###############
### HELPERS ###
###############

function log() {
  echo "$(date +'%F %R'): ${1}" >> "$log_filepath/$log_mainfile"
}

function info() {
  log "[INFO] ${1}"
}

function logfile() {
  (( log_fileindex++ )) || true
  log_file="${log_filepath}/${log_fileindex}-${1}.log"
}

function exit_error() {
  log "[ERR] ${1}"
  exit 1
}

function urlencode() {
  php -r "echo urlencode('${1/\'/\\\'}');"
}


#################
### FUNCTIONS ###
#################

function cleaning() {
  if [ ! -z "${tmp_dir}" ]; then
    rm -r "${tmp_dir}"
  fi
}

function set_logpermissions() {
  mkdir -p "${log_filepath}"
  chown root: "${log_filepath}"
  chmod 0700 "${log_filepath}"
}

function install_packages() {
  logfile ${FUNCNAME[0]}

  apt-get install --no-install-recommends jq udisks-glue php5-fpm -y --force-yes &>> $log_file
}

function find_hypercubefile() {
  logfile ${FUNCNAME[0]}

  hypercube_file=$(find /media/ -mindepth 2 -maxdepth 2 -regex '.*/install\.hypercube\(\.txt\)?$' | head -n1)

  if [ -z "${hypercube_file}" ]; then
    hypercube_file=$(find /root/ -mindepth 1 -maxdepth 1 -regex '.*/install\.hypercube\(\.txt\)?$' | head -n1)
  fi

  if [ ! -z "${hypercube_file}" ]; then
    info "Found HyperCube file: ${hypercube_file}"
  fi
}

function load_json() {
  logfile ${FUNCNAME[0]}

  json=$(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' "${hypercube_file}" 2>> $log_file)

  if [ -z "$json" ]; then
    exit_error "Empty HyperCube (or JSON syntax error)"
  fi
}

function extract_settings() {
  logfile ${FUNCNAME[0]}

  local subjson=$(echo -e "${json}" | grep "^${1}=" | cut -d= -f2-)
  local vars=$(echo "${subjson}" | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' 2>> $log_file)

  if [ -z "$vars" ]; then
    exit_error "${1} settings not found (or JSON syntax error)"
  fi

  IFS=$'\n'; for i in $vars; do
    local key=$(echo $i | cut -d= -f1)
    local value=$(echo $i | cut -d= -f2-)

    settings[$1,$key]=$value

    if [[ ! -z "$value" && ( "$key" =~ ^crt_ || "$key" =~ _passphrase$ || "$key" =~ _password$ ) ]]; then
      echo "settings[$1,$key]=/removed/" &>> $log_file
    else
      echo "settings[$1,$key]=$value" &>> $log_file
    fi
  done
}

function extract_dotcube() {
  logfile ${FUNCNAME[0]}

  local subjson=$(echo -e "${json}" | grep "^vpnclient=" | cut -d= -f2-)

  if [ -z "$subjson" ]; then
    exit_error "vpnclient settings not found"
  fi

  echo "${subjson}" >> "${tmp_dir}/config.cube"
}


######################
### CORE FUNCTIONS ###
######################

function detect_wifidevice() {
  logfile ${FUNCNAME[0]}
  local ynh_wifi_device=$(yunohost app setting hotspot wifi_device 2> /dev/null)

  if [ "${ynh_wifi_device}" == none ]; then
    info "Wifi device missing"

    ynh_wifi_device=$(iw_devices | awk -F\| '{ print $1 }')

    if [ ! -z "${ynh_wifi_device}" ]; then
      info "Wifi device detected: ${ynh_wifi_device}"

      systemctl stop ynh-hotspot &>> $log_file
      yunohost app setting hotspot wifi_device -v "${ynh_wifi_device}" &>> $log_file
      yunohost app setting hotspot service_enabled -v 1 &>> $log_file
      systemctl start ynh-hotspot &>> $log_file
    else
      info "No wifi device detected :("
    fi
  fi
}

function deb_changepassword() {
  logfile ${FUNCNAME[0]}

  # TODO: Remove service asking to change Debian password at first login
  echo "root:${settings[yunohost,password]}" | /usr/sbin/chpasswd
  echo "root:${settings[yunohost,password]}" &>> $log_file
}

function deb_upgrade() {
  logfile ${FUNCNAME[0]}

  apt-get update -qq &>> $log_file
  apt-get dist-upgrade -o Dpkg::Options::='--force-confold' -y --force-yes &>> $log_file || true
  apt-get autoremove -y --force-yes &>> $log_file || true
}

function deb_updatehosts() {
  logfile ${FUNCNAME[0]}

  echo "127.0.0.1 ${settings[yunohost,domain]} ${settings[yunohost,add_domain]}" >> /etc/hosts
  echo "::1 ${settings[yunohost,domain]} ${settings[yunohost,add_domain]}" >> /etc/hosts

  cat /etc/hosts &>> $log_file
}

function ynh_postinstall() {
  logfile ${FUNCNAME[0]}

  yunohost tools postinstall -d "${settings[yunohost,domain]}" -p "${settings[yunohost,password]}" &>> $log_file
}

function ynh_installdkim() {
  logfile ${FUNCNAME[0]}

  hypercube_dkim.sh "${settings[yunohost,domain]}" &>> $log_file
  echo $(cat /etc/opendkim/keys/${settings[yunohost,domain]}/mail.txt) | sed 's/" "//; s/.*"\([^"]\+\)".*/\1/' > "${log_filepath}/dkim-dns-record.TXT"
}

function ynh_removedyndns() {
  rm -f /etc/cron.d/yunohost-dyndns
}

function ynh_createuser() {
  logfile ${FUNCNAME[0]}

  # TODO: https://dev.yunohost.org/issues/228
  yunohost user create "${settings[yunohost,user]}" -f "${settings[yunohost,user_firstname]}" -l "${settings[yunohost,user_lastname]}" -m "${settings[yunohost,user]}@${settings[yunohost,domain]}" -q 0 -p "${settings[yunohost,user_password]}" --admin-password "${settings[yunohost,password]}" # &>> $log_file
}

function install_vpnclient() {
  logfile ${FUNCNAME[0]}

  yunohost app install https://github.com/labriqueinternet/vpnclient_ynh\
    --args "domain=$(urlencode "${settings[yunohost,domain]}")&path=/vpnadmin" &>> $log_file
}

function install_hotspot() {
  logfile ${FUNCNAME[0]}

  yunohost app install https://github.com/labriqueinternet/hotspot_ynh\
    --args "domain=$(urlencode "${settings[yunohost,domain]}")&path=/wifiadmin&wifi_ssid=$(urlencode "${settings[hotspot,wifi_ssid]}")&wifi_passphrase=$(urlencode "${settings[hotspot,wifi_passphrase]}")&firmware_nonfree=$(urlencode "${settings[hotspot,firmware_nonfree]}")" &>> $log_file
}

function configure_hotspot() {
  logfile ${FUNCNAME[0]}
  local ynh_wifi_device=

  yunohost app addaccess hotspot -u "${settings[yunohost,user]}" &>> $log_file

  yunohost app setting hotspot ip6_dns0 -v "${settings[hotspot,ip6_dns0]}" &>> $log_file
  yunohost app setting hotspot ip6_dns1 -v "${settings[hotspot,ip6_dns1]}" &>> $log_file
  yunohost app setting hotspot ip4_dns0 -v "${settings[hotspot,ip4_dns0]}" &>> $log_file
  yunohost app setting hotspot ip4_dns1 -v "${settings[hotspot,ip4_dns1]}" &>> $log_file
  yunohost app setting hotspot ip4_nat_prefix -v "${settings[hotspot,ip4_nat_prefix]}" &>> $log_file

  ynh_wifi_device=$(yunohost app setting hotspot wifi_device 2> /dev/null)

  if [ "${ynh_wifi_device}" == none ]; then
    yunohost app setting hotspot service_enabled -v 1 &>> $log_file
  fi
}

function configure_vpnclient() {
  logfile ${FUNCNAME[0]}

  yunohost app addaccess vpnclient -u "${settings[yunohost,user]}" &>> $log_file

  yunohost app setting vpnclient service_enabled -v 1 &>> $log_file
  ynh-vpnclient-loadcubefile.sh -u "${settings[yunohost,user]}" -p "${settings[yunohost,user_password]}" -c "${tmp_dir}/config.cube" &>> $log_file || true
}


########################
### GLOBAL VARIABLES ###
########################

declare -A settings
tmp_dir=$(mktemp -dp /tmp/ labriqueinternet-installhypercube-XXXXX)
log_filepath=/var/log/hypercube/
log_mainfile=install.log
log_fileindex=0
log_file=
hypercube_file=
json=


##############
### SCRIPT ###
##############

trap cleaning EXIT
trap cleaning ERR

set_logpermissions

# HyperCube installed
if [ -f /etc/yunohost/installed ]; then
  info "Detecting wifi device (if necessary)"
  detect_wifidevice

  info "Removing HyperCube scripts"
  systemctl disable hypercube
  rm -f /etc/systemd/system/hypercube.service
  rm -f /usr/local/bin/hypercube{,_dkim}.sh

# HyperCube not installed
else
  info "Installing some additional required packages"
  install_packages

  info "Looking for HyperCube file"
  find_hypercubefile
  
  if [ -z "${hypercube_file}" ]; then
    exit_error "No install.hypercube(.txt) file found"
  fi
  
  info "Loading JSON"
  load_json
  
  info "Extracting settings for Wifi Hotspot"
  extract_settings hotspot
  
  info "Extracting settings for YunoHost"
  extract_settings yunohost

  info "Extracting settings for VPN Client (logging purposes)"
  extract_settings vpnclient
  
  info "Extracting dot cube file for VPN Client"
  extract_dotcube

  info "Updating Debian root password"
  deb_changepassword

  info "Updating hosts file"
  deb_updatehosts
  
  info "Upgrading Debian/YunoHost"
  deb_upgrade
  
  info "Doing YunoHost post-installation"
  ynh_postinstall

  info "Installing DKIM"
  ynh_installdkim

  if ! [[ "${settings[yunohost,domain]}" =~ \.nohost\.me$ || "${settings[yunohost,domain]}" =~ \.noho\.st$ ]]; then
    info "Removing DynDNS cron"
    ynh_removedyndns
  fi

  info "Creating first user"
  ynh_createuser
  
  info "Installing VPN Client"
  install_vpnclient
  
  info "Installing Wifi Hotspot"
  install_hotspot

  info "Configuring VPN Client"
  configure_vpnclient
  
  info "Configuring Wifi Hotspot"
  configure_hotspot
  
  info "Rebooting"
  systemctl reboot
fi

exit 0
