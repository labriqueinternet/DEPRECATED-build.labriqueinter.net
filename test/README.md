# How to test the image

## For booting in QEMU

* See https://romanrm.net/a10/qemu
* TODO How to build -vexpress kernel for qemu ?
* TODO how to inject the hypercube

1. `wget https://mirrors.romanrm.net/sunxi/qemu/vmlinuz-3.2.0-4-vexpress`
1. `wget https://mirrors.romanrm.net/sunxi/qemu/initrd.img-3.2.0-4-vexpress`
1. `qemu-img convert -f raw -O qcow2 internetcube-stretch-3.6.5.3-lime2-stable.img test.qcow2`
1. `qemu-img resize test.qcow2 10G`
1. `qemu-system-arm -M vexpress-a9 -cpu cortex-a7 -m 1024 -kernel vmlinuz-4.19.62-sunxi -initrd uInitrd-4.19.62-sunxi -append root=/dev/mmcblk0p1 -drive if=sd,cache=unsafe,file=test.qcow2,format=qcow2 -net nic -net bridge,br=virbr0 -serial stdio`

## Setup a local openvpn server for testing

* Only needed for testing the openvpn client app
* See https://github.com/kylemanna/docker-openvpn/blob/master/docs/docker-compose.md

1. `docker-compose run --rm openvpn ovpn_genconfig -u udp://openvpn-test.local`
1. `docker-compose run --rm openvpn ovpn_initpki`
1. `export CLIENTNAME="test"`
1. `docker-compose run --rm openvpn easyrsa build-client-full $CLIENTNAME nopass`
1. `docker-compose run --rm openvpn ovpn_getclient $CLIENTNAME > $CLIENTNAME.ovpn`
1. Fill https://install.internetcu.be/#welcome for generating the
   hypercube
1. `docker-compose up -d openvpn`

## Generate the patched img with the hypercube for install
1. `./install-sd.sh -s /dev/sdX -f ../internetcube-stretch-3.6.5.3-lime2-6145377.img -y test.hypercube -2`
1. `firefox http://192.168.1.14:2468/install.html`
