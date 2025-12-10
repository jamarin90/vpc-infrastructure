#!/bin/bash

# Script para eliminar clientes de WireGuard
# Uso: ./remove-client.sh nombre-cliente

set -e

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

# Verificar argumento
if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <nombre-cliente>"
    echo ""
    echo "Clientes existentes:"
    ls -1 ~/wireguard-clients/*.conf 2>/dev/null | xargs -n 1 basename | sed 's/.conf$//' || echo "Ninguno"
    exit 1
fi

CLIENT_NAME=$1
CLIENTS_DIR=~/wireguard-clients

# Verificar que el cliente existe
if [ ! -f $CLIENTS_DIR/"$CLIENT_NAME.conf" ]; then
    echo "❌ El cliente '$CLIENT_NAME' no existe"
    echo ""
    echo "Clientes disponibles:"
    ls -1 $CLIENTS_DIR/*.conf 2>/dev/null | xargs -n 1 basename | sed 's/.conf$//' || echo "Ninguno"
    exit 1
fi

echo "========================================="
echo "Eliminando cliente: $CLIENT_NAME"
echo "========================================="
echo ""

# Confirmar eliminación
read -p "¿Estás seguro de eliminar el cliente '$CLIENT_NAME'? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Cancelado"
    exit 1
fi

# Obtener llave pública del cliente
CLIENT_PUB_KEY=$(grep "PublicKey" $CLIENTS_DIR/$CLIENT_NAME.conf | awk '{print $3}')

echo "🔑 Llave pública del cliente: $CLIENT_PUB_KEY"

# Eliminar del servidor WireGuard
echo "⚙️  Eliminando del servidor..."
wg set wg0 peer "$CLIENT_PUB_KEY" remove 2>/dev/null || echo "Cliente no estaba activo en WireGuard"

# Crear backup antes de modificar configuración
cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.backup

# Eliminar de la configuración del servidor
echo "📝 Actualizando configuración..."

# Crear archivo temporal sin el cliente
awk -v client="$CLIENT_NAME" '
    /^# Cliente:/ {
        if ($3 == client) {
            skip = 1
            next
        }
    }
    /^# Cliente:/ {
        skip = 0
    }
    /^\[Peer\]/ && skip {
        next
    }
    skip && /^[A-Za-z]/ {
        next
    }
    !skip || /^\[Interface\]/ {
        print
        skip = 0
    }
' /etc/wireguard/wg0.conf > /etc/wireguard/wg0.conf.tmp

mv /etc/wireguard/wg0.conf.tmp /etc/wireguard/wg0.conf

# Mover archivos del cliente a carpeta de eliminados
DELETED_DIR=$CLIENTS_DIR/deleted
mkdir -p $DELETED_DIR

echo "🗑️  Moviendo archivos a carpeta de eliminados..."
mv $CLIENTS_DIR/$CLIENT_NAME.conf $DELETED_DIR/ 2>/dev/null || true
mv $CLIENTS_DIR/$CLIENT_NAME.txt $DELETED_DIR/ 2>/dev/null || true

# Crear registro de eliminación
cat > $DELETED_DIR/$CLIENT_NAME-deleted.txt <<EOF
Cliente: $CLIENT_NAME
Fecha de eliminación: $(date)
Llave pública: $CLIENT_PUB_KEY

Este cliente fue eliminado del servidor.
La configuración se guardó aquí por seguridad.

Para restaurar:
  1. Copia la configuración de vuelta
  2. Agrega la sección [Peer] a /etc/wireguard/wg0.conf
  3. Recarga WireGuard: wg syncconf wg0 <(wg-quick strip wg0)
EOF

# Recargar configuración
echo "🔄 Recargando WireGuard..."
systemctl restart wg-quick@wg0

echo ""
echo "✅ Cliente '$CLIENT_NAME' eliminado correctamente"
echo ""
echo "📊 Estado actual:"
wg show
echo ""
echo "💾 Archivos del cliente movidos a: $DELETED_DIR/"
echo "💾 Backup de configuración: /etc/wireguard/wg0.conf.backup"
echo ""
echo "🔍 Clientes restantes:"
ls -1 $CLIENTS_DIR/*.conf 2>/dev/null | xargs -n 1 basename | sed 's/.conf$//' || echo "Ninguno"
echo ""
