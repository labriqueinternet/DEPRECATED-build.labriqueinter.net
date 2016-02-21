#!/bin/bash

# LaBriqueInternet HyperCube Installer
# Copyright (C) 2015 Julien Vaubourg <julien@vaubourg.com>
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
## Write logs in separate files? One file a function?
## Check: bind9, dnsmasq/nslcd/spamassassin in syslog, post_user_create
##

set -e
set -x


###############
### HELPERS ###
###############

function log() {
  echo $(date) ": ${1}" >> $log_file
}

function info() {
  log "[INFO] ${1}"
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

  echo "--------" >> "${log_file}"
}

function set_logpermissions() {
  touch "${log_file}"
  chown root: "${log_file}"
  chmod 0700 "${log_file}"
}

function install_packages() {
  apt-get install jq udisks-glue php5-fpm -y --force-yes &>> $log_file
}

function find_hypercubefile() {
  hypercube_file=$(find /media/ -mindepth 2 -maxdepth 2 -regex '.*/install\.hypercube\(\.txt\)?$' | head -n1)

  if [ -z "${hypercube_file}" ]; then
    hypercube_file=$(find /root/ -mindepth 1 -maxdepth 1 -regex '.*/install\.hypercube\(\.txt\)?$' | head -n1)
  fi

  if [ ! -z "${hypercube_file}" ]; then
    info "Found HyperCube file: ${hypercube_file}"
  fi
}

function load_json() {
  json=$(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' "${hypercube_file}")
}

function extract_settings() {
  local subjson=$(echo -e "${json}" | grep "^${1}=" | cut -d= -f2-)
  local vars=$(echo "${subjson}" | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]')

  info "Settings ${1}: ${subjson}"

  IFS=$'\n'; for i in $vars; do
    local key=$(echo $i | cut -d= -f1)
    local value=$(echo $i | cut -d= -f2-)

    settings[$1,$key]=$value
  done
}

function extract_dotcube() {
  local subjson=$(echo -e "${json}" | grep "^vpnclient=" | cut -d= -f2-)

  info "Settings vpnclient: ${subjson}"

  echo "${subjson}" >> "${tmp_dir}/config.cube"
}


######################
### CORE FUNCTIONS ###
######################

function detect_wifidevice() {
  local ynh_wifi_device=$(yunohost app setting hotspot wifi_device 2> /dev/null)

  if [ "${ynh_wifi_device}" == none ]; then
    info "HyperCube installed but without working Wifi Hotspot"

    ynh_wifi_device=$(iw_devices | awk -F\| '{ print $1 }')

    if [ ! -z "${ynh_wifi_device}" ]; then
      info "Wifi device detected: ${ynh_wifi_device}"

      systemctl stop ynh-hotspot &>> $log_file
      yunohost app setting hotspot wifi_device -v "${ynh_wifi_device}" &>> $log_file
      yunohost app setting hotspot service_enabled -v 1 &>> $log_file
      systemctl start ynh-hotspot &>> $log_file
    else
      info "No wifi device detected"
    fi
  else
    info "Nothing to do"
  fi
}

function deb_changepassword() {
  # TODO: Remove service asking to change Debian password at first login
  echo "root:${settings[yunohost,password]}" | /usr/sbin/chpasswd
}

function deb_upgrade() {
  apt-get update -qq &>> $log_file
  apt-get dist-upgrade -y --force-yes &>> $log_file
  apt-get autoremove -y --force-yes &>> $log_file
}

function deb_updatehosts() {
  echo "127.0.0.1 ${settings[yunohost,domain]} ${settings[yunohost,add_domain]}" >> /etc/hosts
  echo "::1 ${settings[yunohost,domain]} ${settings[yunohost,add_domain]}" >> /etc/hosts
}

function ynh_postinstall() {
  yunohost tools postinstall -d "${settings[yunohost,domain]}" -p "${settings[yunohost,password]}" &>> $log_file
}

function ynh_installdkim() {
  git clone https://github.com/polytan02/yunohost_auto_config_basic "${tmp_dir}/dkim/"

  pushd "${tmp_dir}/dkim/"
  source ./5_opendkim.sh en "${settings[yunohost,domain]}" &>> $log_file
  popd
}

function ynh_removedyndns() {
  rm -f /etc/cron.d/yunohost-dyndns
}

function ynh_createuser() {
  # TODO: Don't ask password (and &>> $log_file)
  yunohost user create "${settings[yunohost,user]}" -f "${settings[yunohost,user_firstname]}" -l "${settings[yunohost,user_lastname]}" -m "${settings[yunohost,user]}@${settings[yunohost,domain]}" -q 0 -p "${settings[yunohost,user_password]}"
}

function install_vpnclient() {
  yunohost app install https://github.com/labriqueinternet/vpnclient_ynh\
    --args "domain=$(urlencode "${settings[yunohost,domain]}")&path=/vpnadmin" &>> $log_file
}

function install_hotspot() {
  yunohost app install https://github.com/labriqueinternet/hotspot_ynh\
    --args "domain=$(urlencode "${settings[yunohost,domain]}")&path=/wifiadmin&wifi_ssid=$(urlencode "${settings[hotspot,wifi_ssid]}")&wifi_passphrase=$(urlencode "${settings[hotspot,wifi_passphrase]}")&firmware_nonfree=$(urlencode "${settings[hotspot,firmware_nonfree]}")" &>> $log_file
}

function configure_hotspot() {
  yunohost app addaccess hotspot -u "${settings[yunohost,user]}" &>> $log_file

  yunohost app setting hotspot ip6_dns0 -v "${settings[hotspot,ip6_dns0]}" &>> $log_file
  yunohost app setting hotspot ip6_dns1 -v "${settings[hotspot,ip6_dns1]}" &>> $log_file
  yunohost app setting hotspot ip4_dns0 -v "${settings[hotspot,ip4_dns0]}" &>> $log_file
  yunohost app setting hotspot ip4_dns1 -v "${settings[hotspot,ip4_dns1]}" &>> $log_file
  yunohost app setting hotspot ip4_nat_prefix -v "${ip4_nat_prefix}" &>> $log_file
}

function configure_vpnclient() {
  yunohost app addaccess vpnclient -u "${settings[yunohost,user]}" &>> $log_file

  ynh-vpnclient-loadcubefile.sh -u "${settings[yunohost,user]}" -p "${settings[yunohost,user_password]}" -c "${tmp_dir}/config.cube" &>> $log_file
}

function reboot_ifnecessary() {
  local ynh_wifi_device=$(yunohost app setting hotspot wifi_device 2> /dev/null)

  if [ -z "${ynh_wifi_device}" ]; then
    info "No wifi device detected: rebooting"
    shutdown -r &>> $log_file
  else
    info "Wifi device detected, no need to reboot"
  fi
}


########################
### GLOBAL VARIABLES ###
########################

declare -A settings
tmp_dir=$(mktemp -dp /tmp/ labriqueinternet-installhypercube-XXXXX)
log_file=/var/log/hypercube-install.log
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
  detect_wifidevice

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

  # TODO: Only if domain are not .noho.st or .nohost.me?
  info "Removing DynDNS cron"
  ynh_removedyndns

  info "Creating first user"
  ynh_createuser
  
  info "Installing VPN Client"
  install_vpnclient
  
  info "Installing Wifi Hotspot"
  install_hotspot
  
  info "Done"

  reboot_ifnecessary
fi

exit 0
