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
    echo -e "${RED}Upgrade has been rejeitado. Você precisa do UBUNTU 20.04 para usar este script${NO_COLOR}"
    exit 1
}

apt-get update
apt --fix-broken install -y
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

# Remove possíveis restos de PHP antigos
apt-get purge -y php7.2* php8.*

# Instala PHP 7.4
echo -e "${GREEN}Instalando PHP 7.4 via PPA Ondrej...${NO_COLOR}"
add-apt-repository ppa:ondrej/php -y && apt-get update
apt-get install -y php7.4 php7.4-cli php7.4-fpm php7.4-mysql php7.4-curl \
    php7.4-xml php7.4-mbstring php7.4-zip php7.4-bcmath php7.4-gd php7.4-soap \
    libapache2-mod-php7.4 unzip || apt --fix-broken install -y

update-alternatives --set php /usr/bin/php7.4

php -v || echo -e "${RED}Erro: PHP 7.4 não foi instalado corretamente${NO_COLOR}"

# Instala ionCube Loader
echo -e "${GREEN}Instalando ionCube Loader...${NO_COLOR}"
cd /opt
mkdir -p ioncube && cd ioncube
wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz

tar -xzf ioncube_loaders_lin_x86-64.tar.gz
PHP_VERSION=7.4
PHP_EXT_DIR=$(php -i | grep extension_dir | awk '{print $5}')
cp "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" "$PHP_EXT_DIR"
echo "zend_extension=${PHP_EXT_DIR}/ioncube_loader_lin_${PHP_VERSION}.so" > "/etc/php/${PHP_VERSION}/apache2/conf.d/00-ioncube.ini"
a2enmod php7.4
systemctl restart apache2

# Download do pacote PNETLab e correção da dependência
cd /tmp
wget --content-disposition -q --show-progress "$URL_PNET_PNETLAB"
if [ -f "/tmp/pnetlab_6.0.0-100_amd64.deb" ]; then
    echo -e "${GREEN}Corrigindo dependência para PHP 7.4...${NO_COLOR}"
    dpkg-deb -R /tmp/pnetlab_6.0.0-100_amd64.deb /tmp/pnetlab_extract
    sed -i 's/php7.2/php7.4/g' /tmp/pnetlab_extract/DEBIAN/control
    dpkg-deb -b /tmp/pnetlab_extract /tmp/pnetlab_fixed.deb
    dpkg -i /tmp/pnetlab_fixed.deb || apt --fix-broken install -y
else
    echo -e "${RED}Pacote /tmp/pnetlab_6.0.0-100_amd64.deb não encontrado.${NO_COLOR}"
fi

# Demais pacotes .deb do PNETLab
cd /tmp
wget --content-disposition -q --show-progress "$URL_KERNEL"
unzip -o /tmp/$KERNEL -d /tmp/pnetlab_kernel && dpkg -i /tmp/pnetlab_kernel/*.deb

wget --content-disposition -q --show-progress "$URL_PRE_DOCKER"
unzip -o /tmp/pre-docker.zip -d /tmp/pre-docker && dpkg -i /tmp/pre-docker/*.deb

wget --content-disposition -q --show-progress "$URL_PNET_TPM"
unzip -o /tmp/swtpm-focal.zip -d /tmp/swtpm-focal && dpkg -i /tmp/swtpm-focal/*.deb

for url in "$URL_PNET_DOCKER" "$URL_PNET_SCHEMA" "$URL_PNET_GUACAMOLE" "$URL_PNET_VPC" "$URL_PNET_DYNAMIPS" "$URL_PNET_WIRESHARK" "$URL_PNET_QEMU"; do
    filename=$(basename "$url")
    wget -q --show-progress "$url"
    dpkg -i "/tmp/$filename" || apt --fix-broken install -y
    sleep 1
done

fgrep "127.0.1.1 pnetlab.example.com pnetlab" /etc/hosts || echo 127.0.2.1 pnetlab.example.com pnetlab >>/etc/hosts 2>/dev/null
echo pnetlab >/etc/hostname 2>/dev/null

apt autoremove -y -q
apt autoclean -y -q

echo -e "${GREEN}Instalação finalizada com sucesso. Reinicie o sistema.${NO_COLOR}"
echo -e "${GREEN}Credenciais padrão: usuário=root senha=pnet${NO_COLOR}"
