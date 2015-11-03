FROM debian:stable
MAINTAINER Émile Morel


COPY init.sh /tmp/init.sh
RUN bash /tmp/init.sh
RUN apt-get install -uy --force-yes qemu-user-static
