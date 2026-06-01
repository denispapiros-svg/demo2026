#!/bin/bash

clear
echo "=========================================================="
echo "  Генератор инструкции: автоматическая замена IP-адресов"
echo "  Вводите новые IP по порядку табличного бланка."
echo "  Если IP прежний — просто нажмите Enter."
echo "==========================================================\n"

# Сбор переменных по порядку таблицы бланка
echo "--- [ Раздел: ISP ] ---"
read -p "1. ISP ens19 IP (дефолт 172.16.1.1): " isp_ens19; isp_ens19=${isp_ens19:-"172.16.1.1"}
read -p "2. ISP ens20 IP (дефолт 172.16.2.1): " isp_ens20; isp_ens20=${isp_ens20:-"172.16.2.1"}

echo -e "\n--- [ Раздел: HQ-RTR ] ---"
read -p "3. HQ-RTR int0 (к ISP) IP/маска (дефолт 172.16.1.2/28): " hq_isp_ip; hq_isp_ip=${hq_isp_ip:-"172.16.1.2/28"}
read -p "4. HQ-RTR int1.100 (VLAN 100) Шлюз (дефолт 192.168.100.1): " hq_v100_ip; hq_v100_ip=${hq_v100_ip:-"192.168.100.1"}
read -p "5. HQ-RTR int1.200 (VLAN 200) Шлюз (дефолт 192.168.200.1): " hq_v200_ip; hq_v200_ip=${hq_v200_ip:-"192.168.200.1"}
read -p "6. HQ-RTR int1.99 (VLAN 99) Шлюз (дефолт 192.168.99.1): " hq_v99_ip; hq_v99_ip=${hq_v99_ip:-"192.168.99.1"}
read -p "7. HQ-RTR Tunnel.0 IP (дефолт 10.10.10.1): " hq_tun_ip; hq_tun_ip=${hq_tun_ip:-"10.10.10.1"}

echo -e "\n--- [ Раздел: BR-RTR ] ---"
read -p "8. BR-RTR int0 (к ISP) IP/маска (дефолт 172.16.2.2/28): " br_isp_ip; br_isp_ip=${br_isp_ip:-"172.16.2.2/28"}
read -p "9. BR-RTR int1 (к BR-SRV) Шлюз (дефолт 192.168.0.1): " br_int1_ip; br_int1_ip=${br_int1_ip:-"192.168.0.1"}
read -p "10. BR-RTR Tunnel.0 IP (дефолт 10.10.10.2): " br_tun_ip; br_tun_ip=${br_tun_ip:-"10.10.10.2"}

echo -e "\n--- [ Раздел: Конечное оборудование ] ---"
read -p "11. HQ-SRV ens18 IP (дефолт 192.168.100.2): " hq_srv_ip; hq_srv_ip=${hq_srv_ip:-"192.168.100.2"}
read -p "12. BR-SRV ens18 IP (дефолт 192.168.0.2): " br_srv_ip; br_srv_ip=${br_srv_ip:-"192.168.0.2"}

# Динамический расчет подсетей, коротких IP и обратных зон
hq_isp_short=$(echo $hq_isp_ip | cut -d'/' -f1)
br_isp_short=$(echo $br_isp_ip | cut -d'/' -f1)

hq_v100_net=$(echo $hq_v100_ip | cut -d'.' -f1-3).0
hq_v200_net=$(echo $hq_v200_ip | cut -d'.' -f1-3).0
hq_v99_net=$(echo $hq_v99_ip | cut -d'.' -f1-3).0
br_net=$(echo $br_int1_ip | cut -d'.' -f1-3).0

isp_hq_net=$(echo $isp_ens19 | cut -d'.' -f1-3).0
isp_br_net=$(echo $isp_ens20 | cut -d'.' -f1-3).0

rev_v100="$(echo $hq_v100_ip | cut -d'.' -f3).$(echo $hq_v100_ip | cut -d'.' -f2).$(echo $hq_v100_ip | cut -d'.' -f1).in-addr.arpa"
rev_v200="$(echo $hq_v200_ip | cut -d'.' -f3).$(echo $hq_v200_ip | cut -d'.' -f2).$(echo $hq_v200_ip | cut -d'.' -f1).in-addr.arpa"

hq_v100_last=$(echo $hq_v100_ip | cut -d'.' -f4)
hq_v200_last=$(echo $hq_v200_ip | cut -d'.' -f4)
hq_srv_last=$(echo $hq_srv_ip | cut -d'.' -f4)

# Генерация итогового файла READY_INSTRUCTION.md
cat > READY_INSTRUCTION.md <<EOF
# Команды демо-экзамена — через cat + комментарии

---

## МОДУЛЬ 1

---

### ISP

\`\`\`bash
# Задаём имя хоста и перезапускаем bash
hostnamectl set-hostname isp && exec bash

# Обновляем пакеты и ставим нужное
apt-get update && apt-get install tzdata iptables -y

# Часовой пояс
timedatectl set-timezone Europe/Moscow

# Переходим в каталог сетевых интерфейсов
cd /etc/net/ifaces

# Создаём директории для двух интерфейсов
mkdir ens19 && mkdir ens20

# Настройки ens19
cat > ens19/options <<'innerEOF'
BOOTPROTO=static
TYPE=eth
innerEOF

# Копируем options для ens20
cp ens19/options ens20/options

# IP-адрес ens19
cat > ens19/ipv4address <<'innerEOF'
${isp_ens19}/28
innerEOF

# IP-адрес ens20
cat > ens20/ipv4address <<'innerEOF'
${isp_ens20}/28
innerEOF

# Включаем ip_forward (строка 10 — меняем 0 на 1)
sed -i 's/^#\?net\.ipv4\.ip_forward\s*=.*/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf

# Применяем настройки сети
systemctl restart network

# NAT для обеих подсетей через внешний интерфейс ens18
iptables -t nat -A POSTROUTING -s ${isp_hq_net}/28 -o ens18 -j MASQUERADE
iptables -t nat -A POSTROUTING -s ${isp_br_net}/28 -o ens18 -j MASQUERADE

# Сохраняем правила iptables
iptables-save >> /etc/sysconfig/iptables
systemctl restart iptables
\`\`\`

---

### HQ-RTR (EcoRouter)

\`\`\`
# Входим в привилегированный режим
en
conf t

# Имя устройства и домен
hostname hq-rtr
ip domain-name au-team.irpo

# Часовой пояс UTC+3
ntp timezone utc+3

# Создаём администратора
username net_admin
password P@ssw0rd
role admin
ex
write memory

# Настраиваем интерфейс ISP
int isp
ip address ${hq_isp_ip}
ex

# Маршрут по умолчанию
ip route 0.0.0.0/0 ${isp_ens19}

# Привязываем физический порт te0 к интерфейсу isp
port te0
service-instance te0/isp
encapsulation untagged
connect ip interface isp
ex
ex
write memory
# Проверка: должен пойти пинг от hq-rtr к 77.88.8.8

# VLAN-интерфейсы
int vl100
ip address ${hq_v100_ip}/27
int vl200
ip address ${hq_v200_ip}/24
int vl99
ip address ${hq_v99_ip}/29
ex

# Тегированные сервис-инстансы на порту te1
port te1
service-instance te1/vl100
encapsulation dot1q 100 exact
rewrite pop 1
connect ip interface vl100
ex
service-instance te1/vl200
encapsulation dot1q 200 exact
rewrite pop 1
connect ip interface vl200
ex
service-instance te1/vl999
encapsulation dot1q 999 exact
rewrite pop 1
connect ip interface vl999
ex
ex
# Проверка: должен пойти пинг от hq-srv к hq-rtr

# GRE-туннель до BR-RTR
int tunnel.0
ip address ${hq_tun_ip}/30
ip tunnel ${hq_isp_short} ${br_isp_short} mode gre
ex
write memory

# OSPF
router ospf 1
ospf router-id ${hq_tun_ip}
passive-interface default
no passive-interface tunnel.0
network $(echo $hq_tun_ip | cut -d'.' -f1-3).0/30 area 0
network ${hq_v100_net}/27 area 0
network ${hq_v200_net}/24 area 0
network ${hq_v99_net}/29 area 0
ex

# MD5-аутентификация на туннеле
int tunnel.0
ip ospf authentication message-digest
ip ospf message-digest-key 1 md5 P@ssw0rd
ex
write memory

# NAT: внешний и внутренние интерфейсы
int isp
ip nat outside
int vl100
ip nat inside
int vl200
ip nat inside
int vl999
ip nat inside
ex

# NAT-пулы и правила
ip nat pool VLAN100 $(echo $hq_v100_ip | cut -d'.' -f1-3).1-$(echo $hq_v100_ip | cut -d'.' -f1-3).30
ip nat pool VLAN200 $(echo $hq_v200_ip | cut -d'.' -f1-3).1-$(echo $hq_v200_ip | cut -d'.' -f1-3).254
ip nat pool VLAN999 $(echo $hq_v99_ip | cut -d'.' -f1-3).1-$(echo $hq_v99_ip | cut -d'.' -f1-3).6
ip nat source dynamic inside-to-outside pool VLAN100 overload interface isp
ip nat source dynamic inside-to-outside pool VLAN200 overload interface isp
ip nat source dynamic inside-to-outside pool VLAN999 overload interface isp
write memory
# Проверка: должен пойти пинг от hq-srv к 77.88.8.8

# DHCP для VLAN200
ip pool VLAN200 $(echo $hq_v200_ip | cut -d'.' -f1-3).2-$(echo $hq_v200_ip | cut -d'.' -f1-3).254
dhcp-server 1
pool VLAN200 1
mask 24
gateway ${hq_v200_ip}
dns ${hq_srv_ip}
domain-name au-team.irpo
ex
exit
int vl200
dhcp-server 1
ex
write memory
\`\`\`

---

### BR-RTR (EcoRouter)

\`\`\`
en
conf t

# Имя и домен
hostname br-rtr
ip domain-name au-team.irpo
ntp timezone utc+3

# Администратор
username net_admin
password P@ssw0rd
role admin
ex
write memory

# Интерфейс ISP
int isp
ip address ${br_isp_ip}
ex

# Дефолтный маршрут
ip route 0.0.0.0/0 ${isp_ens20}

# Физический порт te0 → isp
port te0
service-instance te0/isp
encapsulation untagged
connect ip interface isp
ex
ex
write memory
# Проверка: пинг от br-rtr к 77.88.8.8

# Внутренний интерфейс
int int1
ip address ${br_int1_ip}/27
ex

# Физический порт te1 → int1 (untagged)
port te1
service-instance te1/int1
encapsulation untagged
connect ip interface int1
ex
ex
# Проверка: пинг от br-srv к br-rtr

# GRE-туннель до HQ-RTR
int tunnel.0
ip address ${br_tun_ip}/30
ip tunnel ${br_isp_short} ${hq_isp_short} mode gre
ex
write memory

# OSPF
router ospf 1
ospf router-id ${br_tun_ip}
passive-interface default
no passive-interface tunnel.0
network ${br_net}/27 area 0
network $(echo $br_tun_ip | cut -d'.' -f1-3).0/30 area 0
ex

# MD5 на туннеле
int tunnel.0
ip ospf authentication message-digest
ip ospf message-digest-key 1 md5 P@ssw0rd
ex
write memory

# NAT
int isp
ip nat outside
int int1
ip nat inside
ex
ip nat pool BR-Net $(echo $br_int1_ip | cut -d'.' -f1-3).1-$(echo $br_int1_ip | cut -d'.' -f1-3).14
ip nat source dynamic inside-to-outside pool BR-Net overload interface isp
write memory
# Проверка: пинг от br-srv к 77.88.8.8
\`\`\`

---

### HQ-SRV (Alt Linux)

\`\`\`bash
# Имя хоста и часовой пояс
hostnamectl set-hostname hq-srv.au-team.irpo && timedatectl set-timezone Europe/Moscow && exec bash

# Заходим в каталог интерфейса
cd /etc/net/ifaces/ens18

# Удаляем старый options и создаём новый
rm -f options
cat > options <<'innerEOF'
BOOTPROTO=static
TYPE=eth
innerEOF

# IP-адрес
cat > ipv4address <<'innerEOF'
${hq_srv_ip}/27
innerEOF

# Маршрут по умолчанию
cat > ipv4route <<'innerEOF'
default via ${hq_v100_ip}
innerEOF

# DNS
cat > resolv.conf <<'innerEOF'
search au-team.irpo
nameserver 77.88.8.8
nameserver ${hq_srv_ip}
innerEOF

# Применяем
systemctl restart network

# Создаём пользователя sshuser с uid 2026
useradd sshuser -u 2026
usermod -aG wheel sshuser
echo "P@ssw0rd" | passwd sshuser --stdin

# sudo без пароля для sshuser
echo "sshuser ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# Настройка SSH
cat > /etc/openssh/sshd_config <<'innerEOF'
Port 2026
AllowUsers sshuser
MaxAuthTries 2
Banner /etc/openssh/banner
innerEOF

# Баннер
cat > /etc/openssh/banner <<'innerEOF'
Authorized access only
innerEOF

systemctl restart sshd

# === После появления интернета ===

# Устанавливаем BIND
apt-get update && apt-get install bind bind-utils -y

# Основные настройки BIND
cat > /var/lib/bind/etc/options.conf <<innerEOF
options {
    listen-on { ${hq_srv_ip}; };
    listen-on-v6 { none; };
    forwarders { 77.88.8.8; };
    allow-query { any; };
};
innerEOF

# Добавляем зоны в rfc1912.conf
cat >> /var/lib/bind/etc/rfc1912.conf <<innerEOF

zone "au-team.irpo" {
    type master;
    file "au-team.irpo";
};

zone "${rev_v100}" {
    type master;
    file "${rev_v100}";
};

zone "${rev_v200}" {
    type master;
    file "${rev_v200}";
};
innerEOF

# Копируем шаблоны зон
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/au-team.irpo
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/${rev_v100}
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/${rev_v200}

# Прямая зона
cat > /var/lib/bind/etc/zone/au-team.irpo <<innerEOF
\$TTL 86400
@       IN      SOA     au-team.irpo. root.au-team.irpo. (
                        2024010101 ; serial
                        3600       ; refresh
                        900        ; retry
                        604800     ; expire
                        86400 )    ; minimum
        IN      NS      au-team.irpo.
        IN      A       ${hq_srv_ip}
hq-srv  IN      A       ${hq_srv_ip}
hq-cli  IN      A       $(echo $hq_v200_ip | cut -d'.' -f1-3).2
hq-rtr  IN      A       ${hq_v100_ip}
hq-rtr  IN      A       ${hq_v200_ip}
hq-rtr  IN      A       ${hq_v99_ip}
docker  IN      A       ${isp_ens19}
web     IN      A       ${isp_ens20}
br-srv  IN      A       ${br_srv_ip}
br-rtr  IN      A       ${br_int1_ip}
innerEOF

# Обратная зона
cat > /var/lib/bind/etc/zone/${rev_v100} <<innerEOF
\$TTL 86400
@       IN      SOA     au-team.irpo. root.au-team.irpo. (
                        2024010101 ; serial
                        3600       ; refresh
                        900        ; retry
                        604800     ; expire
                        86400 )    ; minimum
        IN      NS      au-team.irpo.
${hq_v100_last}       IN      PTR     hq-rtr.au-team.irpo.
${hq_srv_last}       IN      PTR     hq-srv.au-team.irpo.
innerEOF

# Обратная зона
cat > /var/lib/bind/etc/zone/${rev_v200} <<innerEOF
\$TTL 86400
@       IN      SOA     au-team.irpo. root.au-team.irpo. (
                        2024010101 ; serial
                        3600       ; refresh
                        900        ; retry
                        604800     ; expire
                        86400 )    ; minimum
        IN      NS      au-team.irpo.
${hq_v200_last}       IN      PTR     hq-rtr.au-team.irpo.
2       IN      PTR     hq-cli.au-team.irpo.
innerEOF

# Генерируем rndc.key и обрезаем лишнее (оставляем только ключ)
rndc-confgen > /var/lib/bind/etc/rndc.key
sed -i '6,\$d' /var/lib/bind/etc/rndc.key

# Права на зоны
chown -R root:named /etc/bind/zone/*

# Запускаем BIND
systemctl enable --now bind.service

# Обновляем resolv.conf на самом сервере
cat > /etc/net/ifaces/ens18/resolv.conf <<innerEOF
search au-team.irpo
nameserver ${hq_srv_ip}
innerEOF

systemctl restart network
# Проверка: ping ya.ru
\`\`\`

---

### BR-SRV (Alt Linux)

\`\`\`bash
# Имя хоста и часовой пояс
hostnamectl set-hostname br-srv.au-team.irpo && timedatectl set-timezone Europe/Moscow && exec bash

cd /etc/net/ifaces/ens18
rm -f options

cat > options <<'innerEOF'
BOOTPROTO=static
TYPE=eth
innerEOF

cat > ipv4address <<'innerEOF'
${br_srv_ip}/27
innerEOF

cat > ipv4route <<'innerEOF'
default via ${br_int1_ip}
innerEOF

cat > resolv.conf <<'innerEOF'
search au-team.irpo
nameserver 77.88.8.8
nameserver ${hq_srv_ip}
innerEOF

systemctl restart network

# Пользователь sshuser
useradd sshuser -u 2026
usermod -aG wheel sshuser
echo "P@ssw0rd" | passwd sshuser --stdin
echo "sshuser ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# SSH
cat > /etc/openssh/sshd_config <<'innerEOF'
Port 2026
AllowUsers sshuser
MaxAuthTries 2
Banner /etc/openssh/banner
innerEOF

# Баннер
cat > /etc/openssh/banner <<'innerEOF'
Authorized access only
innerEOF

systemctl restart sshd
\`\`\`

---

### HQ-CLI

\`\`\`bash
# Имя хоста и часовой пояс
hostnamectl set-hostname hq-cli.au-team.irpo && timedatectl set-timezone Europe/Moscow && exec bash

# После настройки BIND на hq-srv
systemctl restart network

# Проверка DNS
host hq-rtr.au-team.irpo
\`\`\`

---

## МОДУЛЬ 2

---

### ISP

\`\`\`bash
# Устанавливаем nginx и утилиту для htpasswd
apt-get update && apt-get install nginx apache2-htpasswd -y

# SSH на порт 2026
echo "Port 2026" > /etc/openssh/sshd_config && systemctl restart sshd

# NTP-сервер (chrony)
cat > /etc/chrony.conf <<'EOF'
server ntp0.ntp-servers.net iburst prefer minstratum 4
local stratum 5
allow 0.0.0.0/0
EOF

systemctl restart chronyd

# Конфиг nginx: реверс-прокси для web и docker
cat > /etc/nginx/sites-available.d/default.conf <<'EOF'
server {
    listen 80;
    server_name web.au-team.irpo;

    location / {
        proxy_pass http://172.16.1.2:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        auth_basic "Restricted area";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}

server {
    listen 80;
    server_name docker.au-team.irpo;

    location / {
        proxy_pass http://172.16.2.2:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Активируем конфиг
ln -s /etc/nginx/sites-available.d/default.conf /etc/nginx/sites-enabled.d/

# Создаём пользователя для basic-auth
htpasswd -bc /etc/nginx/.htpasswd WEB P@ssw0rd

# Запускаем nginx
systemctl enable --now nginx
\`\`\`

---

### HQ-RTR (Модуль 2)

\`\`\`bash
apt-get update && apt-get install iptables -y

# SSH на порт 2026
echo "Port 2026" > /etc/openssh/sshd_config && systemctl restart sshd

# NTP-клиент
cat > /etc/chrony.conf <<'EOF'
server 172.16.1.1 iburst
EOF

systemctl restart chronyd

# Форвардинг пакетов
sysctl -w net.ipv4.ip_forward=1

# DNAT: проброс портов на внутренний сервер
iptables -t nat -A PREROUTING -p tcp -d 172.16.1.10 --dport 8080 -j DNAT --to-destination 192.168.1.10:80
iptables -t nat -A PREROUTING -p tcp -d 172.16.1.10 --dport 2026 -j DNAT --to-destination 192.168.1.10:2026

# Сохраняем и включаем
iptables-save >> /etc/sysconfig/iptables && systemctl enable --now iptables
\`\`\`

---

### BR-RTR (Модуль 2)

\`\`\`bash
apt-get update && apt-get install iptables -y

# SSH на порт 2026
echo "Port 2026" > /etc/openssh/sshd_config && systemctl restart sshd

# NTP клиент
cat > /etc/chrony.conf <<'EOF'
server 172.16.2.1 iburst
EOF

systemctl restart chronyd

# Форвардинг
sysctl -w net.ipv4.ip_forward=1

# DNAT
iptables -t nat -A PREROUTING -p tcp -d 172.16.2.10 --dport 8080 -j DNAT --to-destination 192.168.3.10:8080
iptables -t nat -A PREROUTING -p tcp -d 172.16.2.10 --dport 2026 -j DNAT --to-destination 192.168.3.10:2026

iptables-save >> /etc/sysconfig/iptables && systemctl enable --now iptables
\`\`\`

---

### HQ-SRV (Модуль 2)

\`\`\`bash
# Устанавливаем LAMP, mdadm, NFS
apt-get update && apt-get install lamp-server mdadm nfs-server nfs-utils -y

# SSH на порт 2026
echo "Port 2026" > /etc/openssh/sshd_config && systemctl restart sshd

# Сбрасываем суперблоки дисков и создаём RAID0
mdadm --zero-superblock --force /dev/sdb /dev/sdc
mdadm --create --verbose /dev/md0 -l 0 -n 2 /dev/sdb /dev/sdc

# Сохраняем конфиг RAID
mdadm --detail --scan --verbose | tee -a /etc/mdadm.conf

# Форматируем и монтируем
mkfs.ext4 /dev/md0

cat >> /etc/fstab <<'EOF'
/dev/md0        /raid   ext4    defaults        0       0
EOF

mkdir -p /raid
mount -av

# Папка для NFS
mkdir -p /raid/nfs
chmod 777 /raid/nfs

# Экспорт NFS
cat > /etc/exports <<'EOF'
/raid/nfs       192.168.2.0/28(rw,no_root_squash)
EOF

exportfs -arv
systemctl enable --now nfs-server

# NTP
cat > /etc/chrony.conf <<'EOF'
server 172.16.1.1 iburst
EOF

systemctl restart chronyd

# Монтируем ISO и копируем веб-файлы
mount /dev/sr0 /mnt/
cp /mnt/web/index.php /var/www/html
cp /mnt/web/logo.png /var/www/html

# Правим подключение к БД в index.php
sed -i 's/\$servername = .*/\$servername = "localhost";/' /var/www/html/index.php
sed -i 's/\$username = .*/\$username = "webc";/' /var/www/html/index.php
sed -i 's/\$password = .*/\$password = "P@ssw0rd";/' /var/www/html/index.php
sed -i 's/\$dbname = .*/\$dbname = "webdb";/' /var/www/html/index.php

# Настраиваем MariaDB
systemctl enable --now mariadb

mariadb -u root <<'SQLEOF'
CREATE DATABASE webdb;
CREATE USER 'webc'@'localhost' IDENTIFIED BY 'P@ssw0rd';
GRANT ALL PRIVILEGES ON webdb.* TO 'webc'@'localhost' WITH GRANT OPTION;
EXIT;
SQLEOF

systemctl enable --now httpd2
\`\`\`

---

### BR-SRV (Модуль 2)

\`\`\`bash
# Устанавливаем всё необходимое
apt-get update && apt-get install docker-engine docker-compose-v2 task-samba-dc ansible sshpass python3-module-pip -y
pip3 install ansible-pylibssh

# Очищаем старый Samba
rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba /var/cache/samba
mkdir -p /var/lib/samba/sysvol

# Провизируем домен (везде Enter, пароль P@ssw0rd)
samba-tool domain provision

# Запускаем Samba
systemctl enable --now samba

# Копируем Kerberos-конфиг
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

systemctl restart samba

# DNS: указываем на HQ-SRV и себя
cat > /etc/net/ifaces/enp7s1/resolv.conf <<'EOF'
search au-team.irpo
nameserver 192.168.1.10
nameserver 127.0.0.1
EOF

systemctl restart network

# Создаём группу hq и 5 пользователей
samba-tool group add hq

for i in {1..5}; do
  samba-tool user add hquser$i P@ssw0rd
  samba-tool user setexpiry hquser$i --noexpiry
  samba-tool group addmembers "hq" hquser$i
done

# NTP
cat >> /etc/chrony.conf <<'EOF'
server 172.16.2.1 iburst
EOF

systemctl restart chronyd

# Ansible inventory
cat > /etc/ansible/hosts <<'EOF'
[Routers]
HQ-RTR ansible_host=192.168.5.1
BR-RTR ansible_host=192.168.3.1

[Clients]
HQ-CLI ansible_host=192.168.2.10

[Servers:vars]
ansible_user=sshuser
ansible_password=P@ssw0rd
ansible_port=2026

[Routers:vars]
ansible_user=net_admin
ansible_password=P@ssw0rd
ansible_port=2026

[Clients:vars]
ansible_user=user
ansible_password=resu
ansible_port=2026

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

# Ansible конфиг
cat > /etc/ansible/ansible.cfg <<'EOF'
[defaults]
inventory = /etc/ansible/hosts
host_key_checking = False
EOF

# Docker
systemctl enable --now docker.service

# Загружаем образы с ISO
mount /dev/sr0 /mnt/
docker load < /mnt/docker/site_latest.tar
docker load < /mnt/docker/mariadb_latest.tar

# Docker Compose
cat > compose.yaml <<'EOF'
services:
  database:
    container_name: db
    image: mariadb:10.11
    restart: always
    ports:
      - "3306:3306"
    environment:
      MARIADB_DATABASE: "testdb"
      MARIADB_USER: "testc"
      MARIADB_PASSWORD: "P@ssw0rd"
      MARIADB_ROOT_PASSWORD: "toor"

  app:
    container_name: testapp
    image: site:latest
    restart: always
    ports:
      - "8080:8000"
    environment:
      DB_TYPE: "maria"
      DB_HOST: "192.168.3.10"
      DB_PORT: "3306"
      DB_NAME: "testdb"
      DB_USER: "testc"
      DB_PASS: "P@ssw0rd"
    depends_on:
      - database
EOF

docker compose up -d
\`\`\`

---

### HQ-CLI (Модуль 2)

\`\`\`bash
# Устанавливаем всё нужное
apt-get update && apt-get install task-auth-ad-sssd libnss-role nfs-utils nfs-clients yandex-browser-stable -y

# SSH на порт 2026
echo "Port 2026" > /etc/openssh/sshd_config && systemctl restart sshd

# DNS
cat > /etc/resolv.conf <<'EOF'
search au-team.irpo
nameserver 192.168.3.10
EOF

# Авторизуемся в домен au-team.irpo (интерактивно)
# realm join au-team.irpo  (или через task-auth-ad-sssd)

# Добавляем группу hq в wheel
roleadd hq wheel

# Ограничение команд sudo (дописываем в sudoers)
echo "Cmnd_Alias      SHELLCMD = /bin/cat, /bin/grep, /usr/bin/id" >> /etc/sudoers

# NFS
mkdir -p /mnt/nfs
chmod 777 /mnt/nfs

cat >> /etc/fstab <<'EOF'
192.168.1.10:/raid/nfs  /mnt/nfs        nfs     defaults        0       0
EOF

mount -av

# NTP
cat > /etc/chrony.conf <<'EOF'
server 172.16.1.1 iburst
EOF

systemctl restart chronyd

# Локальные DNS-записи для nginx на ISP
cat >> /etc/hosts <<'EOF'
172.16.1.1     web.au-team.irpo
172.16.1.1     docker.au-team.irpo
EOF
\`\`\`
EOF

echo -e "\n=========================================================="
echo "  УСПЕХ! Новая инструкция сгенерирована:"
echo "  -> READY_INSTRUCTION.md"
echo "=========================================================="