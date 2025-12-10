#!/bin/bash

# Script de instalación de WireGuard VPN Server
# Para Debian/Ubuntu

set -e

echo "========================================="
echo "Instalación de WireGuard VPN Server"
echo "========================================="
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

# Detectar IP pública del servidor
SERVER_PUB_IP=$(curl -s ifconfig.me)
if [ -z "$SERVER_PUB_IP" ]; then
    echo "❌ No se pudo detectar la IP pública del servidor"
    echo "Por favor, ingresa la IP pública manualmente:"
    read SERVER_PUB_IP
fi

echo "📍 IP pública del servidor: $SERVER_PUB_IP"
echo ""

# Detectar interfaz de red principal
SERVER_NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
echo "🌐 Interfaz de red detectada: $SERVER_NIC"
echo ""

read -p "¿Continuar con la instalación? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Instalación cancelada"
    exit 1
fi

# Actualizar sistema
echo ""
echo "📦 Actualizando sistema..."
apt-get update
apt-get upgrade -y

# Instalar WireGuard
echo ""
echo "🔧 Instalando WireGuard..."
apt-get install -y wireguard qrencode iptables

# Habilitar IP forwarding
echo ""
echo "⚙️  Habilitando IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Crear directorio para configuraciones
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Generar llaves del servidor
echo ""
echo "🔑 Generando llaves del servidor..."
cd /etc/wireguard
wg genkey | tee private.key | wg pubkey > public.key
chmod 600 private.key
chmod 644 public.key

SERVER_PRIV_KEY=$(cat private.key)
SERVER_PUB_KEY=$(cat public.key)

echo "✓ Llave privada del servidor generada"
echo "✓ Llave pública del servidor: $SERVER_PUB_KEY"

# Crear configuración del servidor
echo ""
echo "📝 Creando configuración del servidor..."

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
# Llave privada del servidor
PrivateKey = $SERVER_PRIV_KEY

# Dirección IP del servidor en la VPN
Address = 10.8.0.1/24

# Puerto de escucha
ListenPort = 51820

# Guardar configuración
SaveConfig = false

# Script que se ejecuta al iniciar
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_NIC -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_NIC -j MASQUERADE

# Los clientes se agregarán aquí con el script add-client.sh
EOF

chmod 600 /etc/wireguard/wg0.conf

# Crear directorio para configuraciones de clientes
mkdir -p ~/wireguard-clients
chmod 700 ~/wireguard-clients

# Abrir puerto en firewall
echo ""
echo "🛡️  Configurando firewall..."
ufw allow 51820/udp comment 'WireGuard VPN'
echo "✓ Puerto 51820/UDP abierto"

# Habilitar y arrancar WireGuard
echo ""
echo "🚀 Iniciando WireGuard..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Verificar que está corriendo
if systemctl is-active --quiet wg-quick@wg0; then
    echo "✅ WireGuard instalado y corriendo correctamente"
else
    echo "❌ Error: WireGuard no está corriendo"
    journalctl -u wg-quick@wg0 -n 20
    exit 1
fi

# Crear archivo de información
cat > ~/wireguard-clients/SERVER_INFO.txt <<EOF
===========================================
Información del Servidor WireGuard
===========================================

IP Pública: $SERVER_PUB_IP
Puerto: 51820
Llave Pública: $SERVER_PUB_KEY
Red VPN: 10.8.0.0/24
IP del servidor en VPN: 10.8.0.1

Próxima IP disponible para cliente: 10.8.0.2

Comandos útiles:
  - Ver estado: wg show
  - Ver clientes conectados: wg show wg0 peers
  - Agregar cliente: ./add-client.sh nombre
  - Eliminar cliente: ./remove-client.sh nombre
  - Reiniciar: systemctl restart wg-quick@wg0
  - Logs: journalctl -u wg-quick@wg0 -f

===========================================
EOF

echo ""
echo "========================================="
echo "✅ Instalación completada"
echo "========================================="
echo ""
echo "📊 Estado del servicio:"
systemctl status wg-quick@wg0 --no-pager -l
echo ""
echo "🔍 Configuración activa:"
wg show
echo ""
echo "📋 Próximos pasos:"
echo ""
echo "1. Agregar tu primer cliente:"
echo "   ./add-client.sh mi-laptop"
echo ""
echo "2. Descargar la configuración del cliente a tu máquina:"
echo "   scp root@$SERVER_PUB_IP:~/wireguard-clients/mi-laptop.conf ~/"
echo ""
echo "3. Instalar WireGuard en tu dispositivo:"
echo "   - Linux/Mac: apt/brew install wireguard-tools"
echo "   - Windows: https://www.wireguard.com/install/"
echo "   - iOS/Android: Busca 'WireGuard' en la App Store/Play Store"
echo ""
echo "4. Importar configuración:"
echo "   - Desktop: sudo wg-quick up mi-laptop"
echo "   - Móvil: Escanea el código QR que generó el script"
echo ""
echo "💡 Información guardada en: ~/wireguard-clients/SERVER_INFO.txt"
echo ""
