## TL;DR Run vagrant Cube box


```shell
vagrant box add --name brique https://repo.labriqueinter.net/vagrant/brique.box
vagrant init brique
vagrant up
```

You will probably get this error: Mounting NFS shared folders..
Don't worry, just wait the Cude reboot and run vagrant ssh again.

After the reboot you can ssh into the VM:

```shell
vagrant ssh
```

Enjoy :)

## Build vagrant box

This readme provide a way to build vagrant box for arm. 

### Transform Internet Cube to vagrant 

First download upstream image and mount it:

```shell
mkdir vagrant_brique; cd vagrant_brique
wget https://repo.labriqueinter.net/labriqueinternet_A20LIME_latest_jessie.img.tar.xz
tar -xf labriqueinternet_A20LIME_latest_jessie.img.tar.xz 
qemu-img convert -c -f raw -O qcow2 labriqueinternet_A20LIME_2017-02-05_jessie.img box.img
mkdir temp
sudo qemu-nbd --connect=/dev/nbd0 box.img
sudo mount /dev/nbd0p1 temp
```

Then add vagrant user

```shell
sudo mkdir -p temp/home/vagrant/.ssh; sudo chmod 0700 temp/home/vagrant/.ssh; sudo wget --no-check-certificate https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -O temp/home/vagrant/.ssh/authorized_keys; sudo chmod 0600 temp/home/vagrant/.ssh/authorized_keys; sudo chown -R 2000:2000 temp/home/vagrant/.ssh; echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee temp/etc/sudoers.d/vagrant;
echo -n '' | sudo tee temp/etc/fstab
echo "vagrant:$6$GeRuXxQI$xRQiyYws2.lm2WFY89Jqv.mhTgqQH/FUpctWDNNUV8nAn9kJTqM.tCY/6f.f4pvhZoPmITr9xnIomVm9uMVkA1:17367:0:99999:7:::" | sudo tee -a temp/etc/shadow
sudo sed -e 's/sudo:x:27:/sudo:x:27:vagrant/g' -i temp/etc/group
echo "vagrant:*::" | sudo tee -a temp/etc/gshadow
echo "vagrant:x:2000:2000::/home/vagrant:/bin/bash" | sudo tee -a temp/etc/passwd
echo "vagrant:x:2000:" | sudo tee -a temp/etc/group
```

Add fake wifi module:

```shell
echo mac80211_hwsim | sudo tee -a temp/etc/modules
```

Change disk name:

```shell
sudo sed -e 's/mmcblk0p1/vda1/' -i temp/usr/local/bin/secondrun
sudo sed -e 's/mmcblk0/vda/' -i temp/usr/local/bin/firstrun
```

Disable ssh in first boot (Avoid vagrant provisioning failure):

```shell
sudo sed -i '12 a /sbin/iptables -I INPUT -p tcp --dport 22 -j DROP' temp/usr/local/bin/firstrun
```

Retrieve files for the boot:

```shell
sudo cp temp/boot/initrd.img-3.16.0-4-armmp .
sudo cp temp/boot/vmlinuz-3.16.0-4-armmp .
sudo chown $USER initrd.img-3.16.0-4-armmp 
cp initrd.img-3.16.0-4-armmp initrd.img
cp vmlinuz-3.16.0-4-armmp vmlinuz
wget http://ftp.fr.debian.org/debian/dists/jessie/main/installer-armhf/current/images/netboot/netboot.tar.gz
gunzip netboot.tar.gz
tar xvf netboot.tar
cp debian-installer/armhf/dtbs/vexpress-v2p-ca15-tc1.dtb .
```

Umount image:

```shell
sudo umount temp
sudo qemu-nbd --disconnect /dev/nbd0
rm -r temp
```

Build vagrant box:

```shell
cp ../conf/Vagrantfile-upstream Vagrantfile
cp ../conf/metadata.json .
tar cvzf debian8-arm-brique.box Vagrantfile vmlinuz initrd.img vexpress-v2p-ca15-tc1.dtb metadata.json box.img
vagrant box add --name brique debian8-arm-brique.box
```

#### Test your Vagrant box

```shell
cd /tmp/test
vagrant init brique 
vagrant up --provider=libvirt
vagrant ssh
```

### Build Debian jessie

We assume that you have a bridge (called br0) with an dhcpd listen on it (an
example is write at the end of this readme)

#### Build qemu box

```shell
mkdir debian7-arm
cd debian7-arm
wget http://ftp.fr.debian.org/debian/dists/jessie/main/installer-armhf/current/images/netboot/netboot.tar.gz
gunzip netboot.tar.gz
tar xvf netboot.tar
mkdir -p images/pxeboot 
cp debian-installer/armhf/initrd.gz images/pxeboot 
cp debian-installer/armhf/vmlinuz images/pxeboot
gunzip images/pxeboot/initrd.gz 
mv images/pxeboot/initrd images/pxeboot/initrd.img
sudo modprobe nbd max_part=8
sudo qemu-img create -f qcow2 box.img 20G
sudo virt-install --name debian7-arm --memory 1024 --disk path=box.img,format=qcow2,size=20 --arch armv7l --machine vexpress-a15 --initrd-inject=../conf/preseed.cfg --extra-args="auto=true text console=ttyAMA0 earlycon hostname=debian7-arm url=file:///preseed.cfg" --nographics --network=bridge=br0 --location './' --force --noreboot --debug --boot kernel=images/pxeboot/vmlinuz,initrd=images/pxeboot/initrd.img,dtb=debian-installer/armhf/dtbs/vexpress-v2p-ca15-tc1.dtb
sudo virsh --connect qemu:///system destroy debian7-arm
sudo virsh --connect qemu:///system undefine debian7-arm
```

#### Retrieve kernel for booting


```shell
sudo qemu-nbd --connect=/dev/nbd0 box.img
sudo mount /dev/nbd0p1 /mnt
cp /mnt/vmlinuz-* .
cp /mnt/initrd.img-* .
mv initrd.img-* initrd.img 
mv vmlinuz-* vmlinuz
sudo umount /mnt
sudo qemu-nbd --disconnect /dev/nbd0
```

You can try your box with:

```shell
sudo qemu-system-arm -m 1024M -drive if=sd,file=box.img,cache=writeback -M vexpress-a15 -cpu cortex-a15  -kernel vmlinuz -initrd initrd.img -append "root=/dev/mmcblk0p2 console=ttyAMA0" -dtb debian-installer/armhf/dtbs/vexpress-v2p-ca15-tc1.dtb --no-reboot -nographic -net nic -net bridge,br=br0
```

#### Build Vagrant box

```shell
cp ../conf/metadata.json .
cp ../conf/Vagrantfile-jessie Vagrantfile
cp debian-installer/armhf/dtbs/vexpress-v2p-ca15-tc1.dtb .
tar cvzf debian7-arm.box Vagrantfile vmlinuz initrd.img vexpress-v2p-ca15-tc1.dtb metadata.json box.img
```

#### Test your Vagrant box

```shell
vagrant box add --name debian7-arm-base debian7-arm.box
cd /tmp/test_vagrant
vagrant init debian7-arm-base
vagrant up --provider=libvirt
```

#### Install InternetCube inside

```shell
vagrant ssh

```

### Build Debian stretch

#### Build qemu box

```shell
mkdir debian8-arm
cd debian8-arm
wget http://ftp.fr.debian.org/debian/dists/stable/main/installer-armhf/current/images/netboot/netboot.tar.gz
gunzip netboot.tar.gz
tar xvf netboot.tar
mkdir -p images/pxeboot 
cp debian-installer/armhf/initrd.gz images/pxeboot 
cp debian-installer/armhf/vmlinuz images/pxeboot
gunzip images/pxeboot/initrd.gz 
mv images/pxeboot/initrd images/pxeboot/initrd.img
sudo qemu-img create -f qcow2 box.img 20G
sudo virt-install --name debian8-arm --memory 1024 --disk path=box.img,format=qcow2,size=20 --arch armv7l --machine vexpress-a15 --initrd-inject=../preseed.cfg --extra-args="auto=true text console=ttyAMA0 earlycon hostname=debian8-arm url=file:///preseed.cfg" --nographics --network=bridge=br0 --location './' --force --noreboot --debug --boot kernel=images/pxeboot/vmlinuz,initrd=images/pxeboot/initrd.img,dtb=debian-installer/armhf/dtbs/vexpress-v2p-ca15-tc1.dtb
```


## Bridge for build

```
apt install install bridge-utils dnsmasq 
brctl addbr br0
cp conf/br0 /etc/network/interfaces.d/
cp conf/dnsmasq.conf /etc/dnsmasq.d/
iptables -t nat -A POSTROUTING -o enp0s25 -j MASQUERADE
ifup br0
```
