#!/bin/bash

# Script para agregar clientes a WireGuard
# Uso: ./add-client.sh nombre-cliente

set -e

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

# Verificar argumento
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <nombre-cliente>"
    echo "Ejemplo: $0 mi-laptop"
    exit 1
fi

CLIENT_NAME=$1

# Validar nombre (solo letras, números, guiones)
if [[ ! $CLIENT_NAME =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ El nombre del cliente solo puede contener letras, números, guiones y guiones bajos"
    exit 1
fi

# Verificar que WireGuard está instalado
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "❌ WireGuard no está instalado. Ejecuta ./install.sh primero"
    exit 1
fi

# Verificar que el cliente no existe ya
if [ -f ~/wireguard-clients/"$CLIENT_NAME.conf" ]; then
    echo "❌ El cliente '$CLIENT_NAME' ya existe"
    echo "Archivos existentes:"
    ls -1 ~/wireguard-clients/*.conf 2>/dev/null || echo "Ninguno"
    exit 1
fi

echo "========================================="
echo "Agregando cliente: $CLIENT_NAME"
echo "========================================="
echo ""

# Obtener información del servidor
SERVER_PUB_KEY=$(cat /etc/wireguard/public.key)
SERVER_PUB_IP=$(curl -s ifconfig.me)
SERVER_PORT=51820

# Obtener próxima IP disponible
CLIENTS_DIR=~/wireguard-clients
mkdir -p $CLIENTS_DIR

# Contar clientes existentes para asignar IP
CLIENT_COUNT=$(ls -1 $CLIENTS_DIR/*.conf 2>/dev/null | wc -l)
CLIENT_IP="10.8.0.$((CLIENT_COUNT + 2))"  # Empezar en 10.8.0.2

echo "📍 IP asignada al cliente: $CLIENT_IP"

# Generar llaves del cliente
echo "🔑 Generando llaves del cliente..."
CLIENT_PRIV_KEY=$(wg genkey)
CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)
CLIENT_PRESHARED_KEY=$(wg genpsk)

echo "✓ Llaves generadas"

# Crear configuración del cliente
echo ""
echo "📝 Creando configuración del cliente..."

cat > $CLIENTS_DIR/$CLIENT_NAME.conf <<EOF
[Interface]
# Llave privada del cliente
PrivateKey = $CLIENT_PRIV_KEY

# IP del cliente en la VPN
Address = $CLIENT_IP/24

# DNS (usa el que prefieras)
DNS = 1.1.1.1, 1.0.0.1

[Peer]
# Llave pública del servidor
PublicKey = $SERVER_PUB_KEY

# Llave pre-compartida para mayor seguridad
PresharedKey = $CLIENT_PRESHARED_KEY

# IP pública y puerto del servidor
Endpoint = $SERVER_PUB_IP:$SERVER_PORT

# Rutear todo el tráfico por la VPN
# Para split-tunneling, cambia esto (ver README.md)
AllowedIPs = 0.0.0.0/0, ::/0

# Mantener conexión viva (útil detrás de NAT)
PersistentKeepalive = 25
EOF

chmod 600 $CLIENTS_DIR/$CLIENT_NAME.conf

# Agregar cliente a la configuración del servidor
echo ""
echo "⚙️  Agregando cliente al servidor..."

cat >> /etc/wireguard/wg0.conf <<EOF

# Cliente: $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUB_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP/32
EOF

# Recargar configuración de WireGuard
echo "🔄 Recargando WireGuard..."
wg syncconf wg0 <(wg-quick strip wg0)

echo "✅ Cliente agregado correctamente"
echo ""

# Mostrar información
echo "========================================="
echo "Información del cliente"
echo "========================================="
echo ""
echo "Nombre: $CLIENT_NAME"
echo "IP en VPN: $CLIENT_IP"
echo "Archivo de configuración: $CLIENTS_DIR/$CLIENT_NAME.conf"
echo ""

# Generar código QR para móviles
echo "📱 Código QR para dispositivos móviles:"
echo ""
qrencode -t ansiutf8 < $CLIENTS_DIR/$CLIENT_NAME.conf
echo ""

echo "========================================="
echo "Cómo usar esta configuración"
echo "========================================="
echo ""
echo "📥 Opción 1: Descargar archivo (Desktop)"
echo ""
echo "En tu computadora local, ejecuta:"
echo "  scp root@$SERVER_PUB_IP:~/wireguard-clients/$CLIENT_NAME.conf ~/"
echo ""
echo "Luego:"
echo "  # Linux/Mac"
echo "  sudo cp ~/$CLIENT_NAME.conf /etc/wireguard/"
echo "  sudo wg-quick up $CLIENT_NAME"
echo ""
echo "  # Windows"
echo "  - Abre WireGuard GUI"
echo "  - Importa el archivo .conf"
echo "  - Activa la conexión"
echo ""
echo "📱 Opción 2: Escanear QR (Móvil)"
echo ""
echo "  1. Instala WireGuard desde App Store/Play Store"
echo "  2. Abre la app"
echo "  3. Presiona '+' > 'Create from QR code'"
echo "  4. Escanea el código QR de arriba"
echo ""
echo "🔍 Verificar conexión:"
echo ""
echo "En el servidor:"
echo "  wg show"
echo ""
echo "En el cliente (conectado):"
echo "  # Ver configuración"
echo "  wg show"
echo ""
echo "  # Verificar IP (debe ser la del servidor)"
echo "  curl ifconfig.me"
echo ""
echo "  # Hacer ping al servidor VPN"
echo "  ping 10.8.0.1"
echo ""

# Guardar información del cliente
cat > $CLIENTS_DIR/$CLIENT_NAME.txt <<EOF
Cliente: $CLIENT_NAME
IP: $CLIENT_IP
Fecha de creación: $(date)
Llave pública: $CLIENT_PUB_KEY

Para conectar:
  Desktop: wg-quick up $CLIENT_NAME
  Móvil: Escanear código QR

Para desconectar:
  Desktop: wg-quick down $CLIENT_NAME
  Móvil: Desactivar en la app
EOF

echo "💾 Información guardada en: $CLIENTS_DIR/$CLIENT_NAME.txt"
echo ""
echo "✅ ¡Listo! Cliente '$CLIENT_NAME' configurado"
echo ""
