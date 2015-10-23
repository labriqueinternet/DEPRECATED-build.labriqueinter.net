FROM debian:stable
MAINTAINER Émile Morel

# U-boot part
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true
ENV LC_ALL C
ENV LANGUAGE C
ENV LANG C
RUN apt-get update
RUN apt-get install --force-yes -y curl ncurses-dev u-boot-tools build-essential git vim libusb-1.0-0-dev pkg-config bc netpbm wget bzip2 debootstrap dpkg-dev qemu binfmt-support qemu-user-static apt-cacher device-tree-compiler
RUN echo deb http://emdebian.org/tools/debian/ jessie main > /etc/apt/sources.list.d/emdebian.list
RUN curl http://emdebian.org/tools/debian/emdebian-toolchain-archive.key | apt-key add -
RUN dpkg --add-architecture armhf
RUN apt-get update
RUN apt-get install --force-yes -y crossbuild-essential-armhf
