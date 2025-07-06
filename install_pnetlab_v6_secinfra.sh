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

lsb_release -r -s | grep -q 20.04 || {
    echo -e "${RED}Upgrade has been rejected. You need to have UBUNTU 20.04 to use this script${NO_COLOR}"
    exit 1
}

apt-get update
apt-get install -y software-properties-common curl gnupg lsb-release

sed -i -e "s/.*PermitRootLogin .*/PermitRootLogin yes/" /etc/ssh/sshd_config &>/dev/null
sed -i -e 's/.*DefaultTimeoutStopSec=.*/DefaultTimeoutStopSec=5s/' /etc/systemd/system.conf &>/dev/null
systemctl restart ssh &>/dev/null

[ ! -e /opt/ovf/.configured ] && echo root:pnet | chpasswd &>/dev/null

systemd-detect-virt -v >/tmp/hypervisor
grep -Eq 'kvm|none' /tmp/hypervisor && {
    ROOTLV=$(mount | grep ' / ' | awk '{print $1}')
    lvextend -l +100%FREE "$ROOTLV"
    resize2fs "$ROOTLV"
}

rm /var/lib/dpkg/lock* &>/dev/null
apt-get install -y ifupdown unzip &>/dev/null

echo -e "${GREEN}Instalando compilador e dependências de build...${NO_COLOR}"
apt-get install -y build-essential autoconf bison re2c gcc g++ make \
    libxml2-dev libssl-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libonig-dev \
    libzip-dev libsqlite3-dev libmysqlclient-dev libfreetype6-dev pkg-config wget unzip || {
    echo -e "${RED}Erro ao instalar dependências de compilação${NO_COLOR}"
    exit 1
}

export PATH=$PATH:/usr/local/bin:/usr/local/php7.2/bin

echo -e "${GREEN}Compilando PHP 7.2 a partir do código-fonte...${NO_COLOR}"
cd /usr/local/src
wget -q https://www.php.net/distributions/php-7.2.34.tar.gz
rm -rf php-7.2.34 && tar -xzf php-7.2.34.tar.gz
cd php-7.2.34

./configure --prefix=/usr/local/php7.2 \
  --with-config-file-path=/usr/local/php7.2/etc \
  --enable-mbstring \
  --with-curl \
  --with-openssl \
  --with-mysqli \
  --with-pdo-mysql \
  --with-zlib \
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
  --enable-sysvshm || {
    echo -e "${RED}Erro ao configurar o PHP 7.2${NO_COLOR}"
    exit 1
}

make -j"$(nproc)" || { echo -e "${RED}Erro ao compilar o PHP${NO_COLOR}"; exit 1; }
make install || { echo -e "${RED}Erro ao instalar o PHP${NO_COLOR}"; exit 1; }

rm -f /usr/bin/php /usr/bin/php7.2
ln -s /usr/local/php7.2/bin/php /usr/bin/php7.2
ln -s /usr/local/php7.2/bin/php /usr/bin/php

php -v || echo -e "${RED}Erro: PHP 7.2 nao foi instalado corretamente${NO_COLOR}"

apt-get purge -y docker.io containerd runc php7.4* php8* -q &>/dev/null

cd /tmp
rm -rf /tmp/* &>/dev/null

wget -q --content-disposition $URL_KERNEL && unzip $KERNEL && dpkg -i pnetlab_kernel/*.deb
wget -q --content-disposition $URL_PRE_DOCKER && unzip pre-docker.zip && dpkg -i pre-docker/*.deb
wget -q --content-disposition $URL_PNET_TPM && unzip swtpm-focal.zip && dpkg -i swtpm-focal/*.deb
wget -q --content-disposition $URL_PNET_DOCKER && dpkg -i pnetlab-docker_*.deb
wget -q --content-disposition $URL_PNET_SCHEMA && dpkg -i pnetlab-schema_*.deb
wget -q --content-disposition $URL_PNET_GUACAMOLE && dpkg -i pnetlab-guacamole_*.deb
wget -q --content-disposition $URL_PNET_VPC && dpkg -i pnetlab-vpcs_*.deb
wget -q --content-disposition $URL_PNET_DYNAMIPS && dpkg -i pnetlab-dynamips_*.deb
wget -q --content-disposition $URL_PNET_WIRESHARK && dpkg -i pnetlab-wireshark_*.deb
wget -q --content-disposition $URL_PNET_QEMU && dpkg -i pnetlab-qemu_*.deb
wget -q --content-disposition $URL_PNET_PNETLAB && dpkg -i pnetlab_6*.deb

fgrep "127.0.1.1 pnetlab.example.com pnetlab" /etc/hosts || echo 127.0.2.1 pnetlab.example.com pnetlab >>/etc/hosts
echo pnetlab >/etc/hostname

# Ajustes para GCP e Azure

dmidecode -t bios | grep -q Google && {
    cd /sys/class/net/
    for i in ens*; do echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="'$(cat $i/address)'", ATTR{type}=="1", KERNEL=="ens*", NAME="'$i'"'; done >/etc/udev/rules.d/70-persistent-net.rules
    sed -i -e 's/NAME="ens.*/NAME="eth0"/' /etc/udev/rules.d/70-persistent-net.rules
    sed -i -e 's/ens4/eth0/' /etc/netplan/50-cloud-init.yaml
    sed -i -e 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    apt-mark hold linux-image-gcp
    mv /boot/vmlinuz-*gcp /root
    update-grub2
}

uname -a | grep -q -- "-azure " && {
    apt update
    echo "options kvm_intel nested=1 vmentry_l1d_flush=never" >/etc/modprobe.d/qemu-system-x86.conf
    sed -i -e 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
}

apt --fix-broken install -y
apt autoremove -y -q
apt autoclean -y -q

echo -e "${GREEN}Upgrade has been done successfully${NO_COLOR}"
echo -e "${GREEN}Default credentials: username=root password=pnet Make sure reboot if you install pnetlab first time${NO_COLOR}"
php -v
