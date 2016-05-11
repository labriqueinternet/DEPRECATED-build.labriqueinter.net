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

# Packages: jq udisks-glue php5-fpm ntfs-3g
# TODO: Send dkim dns txt record by mail?

set -e


###############
### HELPERS ###
###############

function log() {
  echo "$(date +'%F %R'): ${1}" | tee -a "$log_filepath/$log_mainfile"
}

function info() {
  log "[INFO] ${1}"
}

function logfile() {
  (( log_fileindex++ )) || true
  log_file="${log_filepath}/$(printf %02d "${log_fileindex}")-${1}.log"
}

function exit_error() {
  log "[ERR] ${1}"

  sleep 1800
  exit 1
}

function urlencode() {
  php -r "echo urlencode('${1/\'/\\\'}');"
}


#################
### FUNCTIONS ###
#################

function cleaning() {
  sleep 5

  if $export_logs; then
    local usb=$(find /media/ -mindepth 1 -maxdepth 1)

    for i in $usb; do
      rm -fr "${i}/hypercube_logs/"
      cp -fr $log_filepath "${i}/hypercube_logs/"
      sync
    done
  fi

  if [ -d "${tmp_dir}" ]; then
    rm -r "${tmp_dir}"
  fi

  if iptables -w -nL INPUT | grep -q 2468; then
    iptables -w -D INPUT -p tcp -s 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16 --dport 2468 -j ACCEPT
  fi
}

function set_logpermissions() {
  mkdir -p "${log_filepath}"
  chown root: "${log_filepath}"
  chmod 0700 "${log_filepath}"
}

function start_logwebserver() {
  pushd "${log_filepath}" &> /dev/null
  python -m SimpleHTTPServer 2468 &> /dev/null &
  popd &> /dev/null

  ( while true; do
      if ! iptables -w -nL INPUT | grep -q 2468; then
        iptables -w -I INPUT 1 -p tcp -s 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16 --dport 2468 -j ACCEPT
      fi
      sleep 1
    done &> /dev/null ) || true &
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
  logfile ${FUNCNAME[0]}

  json=$(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' "${hypercube_file}" 2>> $log_file)

  if [ -z "$json" ]; then
    exit_error "Empty HyperCube (or JSON syntax error)"
  else
    echo SUCCESS >> $log_file
  fi
}

function extract_settings() {
  logfile "${FUNCNAME[0]}-${1}"

  local subjson=$(echo -e "${json}" | grep "^${1}=" | cut -d= -f2-)
  local vars=$(echo "${subjson}" | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' 2>> $log_file)

  if [ -z "$vars" ]; then
    exit_error "${1} settings not found (or JSON syntax error)"
  fi

  IFS=$'\n'; for i in $vars; do
    local key=$(echo "${i}" | cut -d= -f1)
    local value=$(echo "${i}" | cut -d= -f2-)

    settings[$1,$key]="${value}"

    if [[ ! -z "$value" && ( "$key" =~ ^crt_ || "$key" =~ pass(word|phrase) ) ]]; then
      echo "settings[${1},${key}]=/removed/" &>> $log_file
    else
      echo "settings[${1},${key}]=${value}" &>> $log_file
    fi
  done
}

function extract_dotcube() {
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
    echo -n 'WIFI DEVICES: ' >> $log_file
    iw_devices &>> $log_file

    if [ ! -z "${ynh_wifi_device}" ]; then
      info "Wifi device detected: ${ynh_wifi_device}"

      systemctl stop ynh-hotspot &>> $log_file
      yunohost app setting hotspot wifi_device -v "${ynh_wifi_device}" &>> $log_file
      yunohost app setting hotspot service_enabled -v 1 &>> $log_file
      systemctl start ynh-hotspot &>> $log_file
    else
      info "No wifi device detected :("
    fi
  else
    echo Nothing to do >> $log_file
  fi
}

function deb_changepassword() {
  echo "root:${settings[yunohost,password]}" | /usr/sbin/chpasswd
}

function deb_upgrade() {
  logfile ${FUNCNAME[0]}

  apt-get update -qq &>> $log_file
  apt-get dist-upgrade -o Dpkg::Options::='--force-confold' -y --force-yes &>> $log_file || true
  apt-get autoremove -y --force-yes &>> $log_file || true
}

function deb_changehostname() {
  hostnamectl --static set-hostname "${settings[yunohost,domain]}"
  hostnamectl --transient set-hostname "${settings[yunohost,domain]}"
  hostnamectl --pretty set-hostname "Brique Internet (${settings[yunohost,domain]})"
}

function deb_updatehosts() {
  logfile ${FUNCNAME[0]}

  echo "127.0.0.1 ${settings[yunohost,domain]}" >> /etc/hosts
  echo "::1 ${settings[yunohost,domain]}" >> /etc/hosts

  cat /etc/hosts &>> $log_file
}

function ynh_postinstall() {
  logfile ${FUNCNAME[0]}

  yunohost tools postinstall -d "${settings[yunohost,domain]}" -p "${settings[yunohost,password]}" &>> $log_file
}

function check_dyndns_list() {
  logfile ${FUNCNAME[0]}

  local domains_file="${tmp_dir}/domains"
  curl https://dyndns.yunohost.org/domains > $domains_file 2>> $log_file

  local vars=$(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' ${domains_file} 2>> $log_file)

  IFS=$'\n'; for i in $vars; do
    local domain=$(echo "${i}" | cut -d= -f2-)
    echo "dyndns_domain: ${domain}" &>> $log_file

    if [[ "${settings[yunohost,domain]}" =~ "${domain}"$ ]]; then
      is_dyndns_useful=true
      echo "DynDNS is useful: ${domain}" &>> $log_file
    fi
  done
}

function ynh_removedyndns() {
  rm -f /etc/cron.d/yunohost-dyndns
}

function ynh_createuser() {
  logfile ${FUNCNAME[0]}

  yunohost user create "${settings[yunohost,user]}" -f "${settings[yunohost,user_firstname]}" -l "${settings[yunohost,user_lastname]}" -m "${settings[yunohost,user]}@${settings[yunohost,domain]}" -q 0 -p "${settings[yunohost,user_password]}" --admin-password "${settings[yunohost,password]}" &>> $log_file
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

function install_webmail() {
  logfile ${FUNCNAME[0]}

  # Roundcube app should be in the official YunoHost apps organization
  yunohost app install https://github.com/Kloadut/roundcube_ynh\
    --args "domain=$(urlencode "${settings[yunohost,domain]}")&path=/webmail" &>> $log_file
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

function monitoring_ip() {
  logfile ${FUNCNAME[0]}

  (for i in {1-6}; do
      tmplog=$(mktemp /tmp/hypercube-monitoring_ip-XXXX)

      date >> $tmplog
      echo -e "\n" >> $tmplog
      echo IP ADDRESS >> $tmplog
      echo ================= >> $tmplog
      ip addr &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo IP6 ROUTE >> $tmplog
      echo ================= >> $tmplog
      ip -6 route &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo IP4 ROUTE >> $tmplog
      echo ================= >> $tmplog
      ip route &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo RESOLV.CONF >> $tmplog
      echo ================= >> $tmplog
      cat /etc/resolv.conf &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo PING6 WIKIPEDIA.ORG >> $tmplog
      echo ================= >> $tmplog
      ping6 -c 3 wikipedia.org &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo PING4 WIKIPEDIA.ORG >> $tmplog
      echo ================= >> $tmplog
      ping -c 3 wikipedia.org &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo PING 2620:0:862:ed1a::1 >> $tmplog
      echo ================= >> $tmplog
      ping6 -c 3 2620:0:862:ed1a::1 &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo PING 91.198.174.192 >> $tmplog
      echo ================= >> $tmplog
      ping -c 3 91.198.174.192 &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo TRACEROUTE 2620:0:862:ed1a::1 >> $tmplog
      echo ================= >> $tmplog
      traceroute6 -n 2620:0:862:ed1a::1 &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo TRACEROUTE 91.198.174.192 >> $tmplog
      echo ================= >> $tmplog
      traceroute -n 91.198.174.192 &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo IW DEV >> $tmplog
      echo ================= >> $tmplog
      iw dev &>> $tmplog

      mv $tmplog $log_file
      sleep 300
    done) || true &
}

function monitoring_firewalls() {
  logfile ${FUNCNAME[0]}

  (for i in {1-6}; do
      tmplog=$(mktemp /tmp/hypercube-monitoring_firewalls-XXXX)

      date >> $tmplog
      echo -e "\n" >> $tmplog
      echo IP6TABLES -nvL >> $tmplog
      echo ================= >> $tmplog
      ip6tables -nvL &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo IPTABLES -nvL >> $tmplog
      echo ================= >> $tmplog
      iptables -w -nvL &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo 'IPTABLES -t nat -nvL' >> $tmplog
      echo ================= >> $tmplog
      iptables -w -t nat -nvL &>> $tmplog

      mv $tmplog $log_file
      sleep 300
    done) || true &
}

function monitoring_processes() {
  logfile ${FUNCNAME[0]}

  (for i in {1-6}; do
      tmplog=$(mktemp /tmp/hypercube-monitoring_processes-XXXX)

      date >> $tmplog
      echo -e "\n" >> $tmplog
      echo YNH-VPNCLIENT STATUS >> $tmplog
      echo ================= >> $tmplog
      ynh-vpnclient status &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo YNH-HOTSPOT STATUS >> $tmplog
      echo ================= >> $tmplog
      ynh-hotspot status &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo 'PS AUX | GREP OPENVPN' >> $tmplog
      echo ================= >> $tmplog
      ps aux | grep openvpn &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo 'PS AUX | GREP DNSMASQ' >> $tmplog
      echo ================= >> $tmplog
      ps aux | grep dnsmasq &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo 'PS AUX | GREP HOSTAPD' >> $tmplog
      echo ================= >> $tmplog
      ps aux | grep hostapd &>> $tmplog
      echo -e "\n\n" >> $tmplog
      echo 'NETSTAT -pnat' >> $tmplog
      echo ================= >> $tmplog
      netstat -pnat &>> $tmplog

      mv $tmplog $log_file
      sleep 300
    done) || true &
}

function end_installation() {
  log_fileindex=90

  detect_wifidevice

  monitoring_firewalls
  monitoring_processes
  monitoring_ip

  cp /var/log/daemon.log "${log_filepath}/var_log_daemon.log"
  cp /var/log/syslog "${log_filepath}/var_log_syslog.log"

  rm -f /root/install.hypercube

  info "30 minutes before disabling this interface"
  info "Please, wait 5 minutes and save this page with Ctrl+S"
  sleep 1800

  info "Removing HyperCube scripts (this page will be disconnected)"
  sleep 5

  systemctl disable hypercube
}


########################
### GLOBAL VARIABLES ###
########################

declare -A settings
tmp_dir=$(mktemp -dp /tmp/ labriqueinternet-installhypercube-XXXXX)
is_dyndns_useful=false
log_filepath=/var/log/hypercube/
log_mainfile=install.log
log_fileindex=0
log_file=
export_logs=true
hypercube_file=
json=


##############
### SCRIPT ###
##############

trap cleaning EXIT
trap cleaning ERR

# YunoHost was installed without the HyperCube system
if [ -f /etc/yunohost/installed -a ! -f "${log_filepath}/enabled" ]; then
  systemctl disable hypercube
  export_logs=false

  exit 0
fi

udisks-glue
sleep 10

set_logpermissions
start_logwebserver

# firstrun/secondrun not finished
if [ ! -f /etc/yunohost/cube_installed ]; then
  info "Waiting for the end of the FS resizing..."

  exit 0
fi

# Second boot
if [ -f "${log_filepath}/enabled" ]; then
  info "End of installation"
  end_installation

# First boot
else
  info "Looking for HyperCube file"
  find_hypercubefile
  
  if [ -z "${hypercube_file}" ]; then
    export_logs=false
    exit_error "No install.hypercube(.txt) file found"
  fi

  touch "${log_filepath}/enabled"
  
  info "Loading JSON"
  load_json
  
  info "Extracting settings for Wifi Hotspot"
  extract_settings hotspot
  
  info "Extracting settings for YunoHost"
  extract_settings yunohost

  info "Extracting settings for VPN Client (logging purposes)"
  extract_settings vpnclient
  
  info "Extracting .cube file for VPN Client"
  extract_dotcube

  info "Updating Debian root password"
  deb_changepassword

  info "Changing hostname"
  deb_changehostname

  info "Updating hosts file"
  deb_updatehosts

  info "Upgrading Debian/YunoHost..."
  deb_upgrade

  info "Doing YunoHost post-installation..."
  ynh_postinstall

  info "Check online DynDNS domains list"
  check_dyndns_list

  if ! $is_dyndns_useful; then
    info "Removing DynDNS cron"
    ynh_removedyndns
  fi

  info "Creating first user"
  ynh_createuser
  
  info "Installing VPN Client..."
  install_vpnclient
  
  info "Installing Wifi Hotspot..."
  install_hotspot

  info "Configuring VPN Client..."
  configure_vpnclient
  
  info "Configuring Wifi Hotspot..."
  configure_hotspot

  info "Installing Roundcube Webmail..."
  install_webmail || true
  
  info "Rebooting..."

  if [ -f /etc/crypttab ]; then
    info "WARN: Once rebooted, you have to give the passphrase for uncrypting your Cube"
  fi

  sleep 5
  systemctl reboot
fi

exit 0
