#!/bin/bash

# Скрипт для изменения IP-адресов сетевых интерфейсов
# Usage: sudo ./change_ip.sh

set -e

echo "======================================"
echo "  Скрипт изменения IP-адресов"
echo "======================================"
echo ""

# Функция для проверки формата IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 0
    else
        echo "❌ Ошибка: неверный формат IP. Используйте формат: x.x.x.x/xx"
        return 1
    fi
}

# Функция для установки IP на интерфейс
set_interface_ip() {
    local interface=$1
    local ip=$2
    local gateway=$3
    
    echo "🔧 Настройка интерфейса $interface..."
    
    # Проверяем существование директории
    if [ ! -d "/etc/net/ifaces/$interface" ]; then
        mkdir -p "/etc/net/ifaces/$interface"
        echo "   📁 Создана директория /etc/net/ifaces/$interface"
    fi
    
    # Устанавливаем базовые параметры
    cat > "/etc/net/ifaces/$interface/options" <<EOF
BOOTPROTO=static
TYPE=eth
EOF
    
    # Устанавливаем IP-адрес
    echo "$ip" > "/etc/net/ifaces/$interface/ipv4address"
    echo "   ✅ IP установлен: $ip"
    
    # Устанавливаем шлюз (если указан)
    if [ -n "$gateway" ]; then
        cat > "/etc/net/ifaces/$interface/ipv4route" <<EOF
default via $gateway
EOF
        echo "   ✅ Шлюз установлен: $gateway"
    fi
}

# Главное меню
while true; do
    echo ""
    echo "Выберите действие:"
    echo "1. Изменить IP на одном интерфейсе"
    echo "2. Изменить IP на нескольких интерфейсах"
    echo "3. Просмотреть текущие IP"
    echo "4. Применить изменения (restart network)"
    echo "5. Выход"
    echo ""
    read -p "Ваш выбор (1-5): " choice
    
    case $choice in
        1)
            echo ""
            read -p "Введите имя интерфейса (например, ens18): " interface
            read -p "Введите новый IP (формат x.x.x.x/xx): " new_ip
            read -p "Введите шлюз (Enter для пропуска): " gateway
            
            if validate_ip "$new_ip"; then
                set_interface_ip "$interface" "$new_ip" "$gateway"
                echo "✅ Интерфейс $interface настроен"
            fi
            ;;
        2)
            echo ""
            echo "Введите интерфейсы в формате: интерфейс1:IP1:шлюз1 интерфейс2:IP2:шлюз2"
            echo "Пример: ens18:192.168.100.2/27:192.168.100.1 ens19:172.16.1.1/28:"
            echo ""
            read -p "Интерфейсы: " interfaces_string
            
            # Проверяем и применяем каждый интерфейс
            for interface_config in $interfaces_string; do
                IFS=':' read -r interface ip gateway <<< "$interface_config"
                
                if validate_ip "$ip"; then
                    set_interface_ip "$interface" "$ip" "$gateway"
                else
                    echo "⏭️  Пропуск интерфейса $interface из-за неверного IP"
                fi
            done
            ;;
        3)
            echo ""
            echo "Текущие IP-адреса:"
            echo "-------------------"
            for iface_dir in /etc/net/ifaces/*/; do
                iface=$(basename "$iface_dir")
                if [ -f "$iface_dir/ipv4address" ]; then
                    ip=$(cat "$iface_dir/ipv4address")
                    echo "  $iface: $ip"
                fi
            done
            ;;
        4)
            echo ""
            echo "⚡ Применение изменений..."
            systemctl restart network
            echo "✅ Сетевые настройки перезагружены"
            
            echo ""
            echo "Новые IP-адреса:"
            echo "-------------------"
            ip addr show | grep "inet " | awk '{print $2}'
            ;;
        5)
            echo ""
            echo "👋 До свидания!"
            exit 0
            ;;
        *)
            echo "❌ Неверный выбор. Пожалуйста, выберите 1-5"
            ;;
    esac
done
