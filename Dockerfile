FROM debian:latest

# pre reqs
RUN apt update && apt install openssh-server sudo vim x11-apps samba git curl perl libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev libsdl1.2-dev libgtk2.0-dev python2 libncurses5-dev -y

RUN useradd -rm -d /home/user -s /bin/bash -g root -G sudo -u 1001 user
RUN echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# default passwd
RUN echo "root:root" | chpasswd
RUN echo "user:ece391" | chpasswd

# sshd configs
RUN echo "Port 37391" >> /etc/ssh/sshd_config
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
RUN echo "X11UseLocalhost yes" >> /etc/ssh/sshd_config

# start sshd
EXPOSE 37391
# CMD ["/usr/bin/sudo", "/usr/sbin/sshd", "-D"]
ENTRYPOINT sudo service ssh start && sudo service smbd start && bash

# QEMU SETUP
USER user
WORKDIR /home/user

RUN mkdir -p /home/user/ece391

COPY setup_linux.sh /home/user/ece391/
COPY ./ece391/ /home/user/ece391/

WORKDIR /home/user/ece391
RUN sudo chmod 777 ./ece391_share/work/vm/devel.qcow
RUN sudo chmod +x ./setup_linux.sh
RUN ./setup_linux.sh

# docker run -it --network=host -v /tmp/.X11-unix:/tmp/.X11-unix