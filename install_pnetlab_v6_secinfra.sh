#!/bin/bash
clear
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

GREEN='\033[32m'
RED='\033[31m'
NO_COLOR='\033[0m'

KERNEL=pnetlab_kernel.zip
rm /var/lib/dpkg/lock* &>/dev/null
dpkg --configure -a &>/dev/null

# URLs
URL_KERNEL=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/L/linux-5.17.15-pnetlab-uksm/pnetlab_kernel.zip
URL_PRE_DOCKER=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/D/pre-docker.zip
URL_PNET_GUACAMOLE=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/P/PNET_GUACAMOLE/pnetlab-guacamole_6.0.0-7_amd64.deb
URL_PNET_DYNAMIPS=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/P/PNET_DYNAMIPS/pnetlab-dynamips_6.0.0-30_amd64.deb
URL_PNET_SCHEMA=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/P/PNET_SCHEMA/pnetlab-schema_6.0.0-30_amd64.deb
URL_PNET_VPC=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/P/PNET_VPC/pnetlab-vpcs_6.0.0-30_amd64.deb
URL_PNET_QEMU=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/P/PNET_QEMU/pnetlab-qemu_6.0.0-30_amd64.deb
URL_PNET_DOCKER=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/P/PNET_DOCKER/pnetlab-docker_6.0.0-30_amd64.deb
URL_PNET_PNETLAB=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/P/PNET_PNETLAB/pnetlab_6.0.0-100_amd64.deb
URL_PNET_WIRESHARK=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/P/PNET_WIRESHARK/pnetlab-wireshark_6.0.0-30_amd64.deb
URL_PNET_TPM=https://drive.labhub.eu.org/0:/upgrades_pnetlab/Focal/T/swtpm-focal.zip

lsb_release -r -s | grep -q 20.04
if [ $? -ne 0 ]; then
    echo -e "${RED}Upgrade has been rejected. You need to have UBUNTU 20.04 to use this script${NO_COLOR}"
    exit 0
fi

uname -a | grep -q -- "-azure " && (
    ls -l /dev/disk/by-id/ | grep -q sdc && (
        echo o; echo n; echo p; echo 1; echo; echo; echo w
    ) | sudo fdisk /dev/sdc && (
        mke2fs -F /dev/sdc1
        echo "/dev/sdc1 /opt ext4 defaults,discard 0 0" >>/etc/fstab
        mount /opt
    )
)

apt-get update
sed -i -e "s/.*PermitRootLogin .*/PermitRootLogin yes/" /etc/ssh/sshd_config &>/dev/null
sed -i -e 's/.*DefaultTimeoutStopSec=.*/DefaultTimeoutStopSec=5s/' /etc/systemd/system.conf &>/dev/null
systemctl restart ssh &>/dev/null

if [ ! -e /opt/ovf/.configured ]; then
    echo root:pnet | chpasswd &>/dev/null
fi

systemd-detect-virt -v >/tmp/hypervisor
resize() {
    ROOTLV=$(mount | grep ' / ' | awk '{print $1}')
    lvextend -l +100%FREE "$ROOTLV"
    resize2fs "$ROOTLV"
}
fgrep -e kvm -e none /tmp/hypervisor >/dev/null && resize &>/dev/null

rm /var/lib/dpkg/lock* &>/dev/null
apt-get install -y ifupdown unzip &>/dev/null

echo -e "${GREEN}Installing build dependencies...${NO_COLOR}"
apt-get install -y build-essential autoconf bison re2c libxml2-dev libssl-dev \
libcurl4-openssl-dev libjpeg-dev libpng-dev libonig-dev libzip-dev libsqlite3-dev \
libmysqlclient-dev libfreetype6-dev pkg-config unzip wget apache2 mysql-server \
vim dos2unix lsb-release net-tools rsync telnet zip libtool libncurses5 libtinfo5 &>/dev/null

echo -e "${GREEN}Compiling PHP 7.2 from source...${NO_COLOR}"
cd /usr/local/src
wget -q https://www.php.net/distributions/php-7.2.34.tar.gz
tar -xzf php-7.2.34.tar.gz
cd php-7.2.34

./configure --prefix=/usr/local/php7.2 \
  --with-config-file-path=/usr/local/php7.2/etc \
  --enable-mbstring \
  --with-curl \
  --with-openssl \
  --with-mysqli \
  --with-pdo-mysql \
  --with-zlib \
  --with-zip \
  --with-gd \
  --with-jpeg-dir=/usr/lib \
  --with-png-dir=/usr/lib \
  --enable-soap \
  --enable-bcmath \
  --enable-opcache \
  --enable-fpm \
  --with-freetype-dir=/usr/include/freetype2 \
  --with-xmlrpc \
  --with-gettext \
  --enable-sockets \
  --enable-sysvshm

make -j"$(nproc)" && make install

ln -s /usr/local/php7.2/bin/php /usr/bin/php7.2
ln -sf /usr/bin/php7.2 /usr/bin/php

php -v

echo -e "${GREEN}Downloading and installing PNETLab packages...${NO_COLOR}"

apt-get purge -y docker.io containerd runc php7.4* php8* -q &>/dev/null

cd /tmp
rm -rf /tmp/* &>/dev/null

dpkg-query -l | grep linux-image-5.17.15-pnetlab-uksm-2 | grep 5.17.15-pnetlab-uksm-2-1 -q || (
    wget --content-disposition -q --show-progress $URL_KERNEL
    unzip /tmp/$KERNEL &>/dev/null
    dpkg -i /tmp/pnetlab_kernel/*.deb
)

dpkg-query -l | grep docker-ce -q || (
    wget --content-disposition -q --show-progress $URL_PRE_DOCKER
    unzip /tmp/pre-docker.zip &>/dev/null
    dpkg -i /tmp/pre-docker/*.deb
)

dpkg-query -l | grep swtpm -q || (
    wget --content-disposition -q --show-progress $URL_PNET_TPM
    unzip /tmp/swtpm-focal.zip &>/dev/null
    dpkg -i /tmp/swtpm-focal/*.deb
)

wget -q --content-disposition $URL_PNET_DOCKER && dpkg -i /tmp/pnetlab-docker_*.deb
wget -q --content-disposition $URL_PNET_SCHEMA && dpkg -i /tmp/pnetlab-schema_*.deb
wget -q --content-disposition $URL_PNET_GUACAMOLE && dpkg -i /tmp/pnetlab-guacamole_*.deb
wget -q --content-disposition $URL_PNET_VPC && dpkg -i /tmp/pnetlab-vpcs_*.deb
wget -q --content-disposition $URL_PNET_DYNAMIPS && dpkg -i /tmp/pnetlab-dynamips_*.deb
wget -q --content-disposition $URL_PNET_WIRESHARK && dpkg -i /tmp/pnetlab-wireshark_*.deb
wget -q --content-disposition $URL_PNET_QEMU && dpkg -i /tmp/pnetlab-qemu_*.deb
wget -q --content-disposition $URL_PNET_PNETLAB && dpkg -i /tmp/pnetlab_6*.deb

fgrep "127.0.1.1 pnetlab.example.com pnetlab" /etc/hosts || echo 127.0.2.1 pnetlab.example.com pnetlab >>/etc/hosts
echo pnetlab >/etc/hostname

# Cloud tuning
dmidecode -t bios | grep -q Google && (
    cd /sys/class/net/
    for i in ens*; do echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="'$(cat $i/address)'", ATTR{type}=="1", KERNEL=="ens*", NAME="'$i'"'; done >/etc/udev/rules.d/70-persistent-net.rules
    sed -i -e 's/NAME="ens.*/NAME="eth0"/' /etc/udev/rules.d/70-persistent-net.rules
    sed -i -e 's/ens4/eth0/' /etc/netplan/50-cloud-init.yaml
    sed -i -e 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    apt-mark hold linux-image-gcp
    mv /boot/vmlinuz-*gcp /root
    update-grub2
)

uname -a | grep -q -- "-azure " && (
    apt update
    echo "options kvm_intel nested=1 vmentry_l1d_flush=never" >/etc/modprobe.d/qemu-system-x86.conf
    sed -i -e 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
)

apt autoremove -y -q
apt autoclean -y -q
echo -e "${GREEN}Upgrade has been done successfully ${NO_COLOR}"
echo -e "${GREEN}Default credentials: username=root password=pnet Make sure reboot if you install pnetlab first time ${NO_COLOR}"
