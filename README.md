
## 👉 Instalação PNETLAB v6

-  Realize o Download do Ubuntu Server 20.04.6 LTS
```linux
https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-live-server-amd64.iso
```

- 👉 Instale o Ubuntu Server em um servidor bare metal, ou virtualizado, conforme vídeo:

- 👉 Atualize o Sistema Operacional
```linux
apt-get upgrade
apt-get update
```

- 👉 Realize a instalação do PnetLab através do comando:
```linux
bash -c "$(curl -sL https://github.com/matheuscazzi/pnetlab_install/raw/refs/heads/main/install_pnetlab_v6_secinfra.sh)"
```

## 👉 Instalação do Ishare2

- 👉 Realize a instalação do ISHARE2 com o comando abaixo:
```linux
wget -O /usr/sbin/ishare2 https://raw.githubusercontent.com/ishare2-org/ishare2-cli/main/ishare2 && chmod +x /usr/sbin/ishare2 && ishare2
```
