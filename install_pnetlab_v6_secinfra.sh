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

echo -e "${GREEN}Instalando PHP 7.4 via PPA Ondrej...${NO_COLOR}"
add-apt-repository ppa:ondrej/php -y && apt-get update
apt-get install -y php7.4 php7.4-cli php7.4-fpm php7.4-mysql php7.4-curl     php7.4-xml php7.4-mbstring php7.4-zip php7.4-bcmath php7.4-gd php7.4-soap     libapache2-mod-php7.4 unzip

update-alternatives --set php /usr/bin/php7.4

php -v || echo -e "${RED}Erro: PHP 7.4 nao foi instalado corretamente${NO_COLOR}"

# (continua normalmente o restante do script...)
