#!/bin/bash

# Script de verificación de WireGuard VPN

echo "========================================="
echo "Verificación de WireGuard VPN"
echo "========================================="
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_status() {
    local name=$1
    local command=$2

    if eval $command > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name"
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        return 1
    fi
}

echo "1. Estado del servicio"
echo "----------------------------"
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}✓${NC} WireGuard está activo"
else
    echo -e "${RED}✗${NC} WireGuard NO está activo"
    echo "Intenta: systemctl start wg-quick@wg0"
fi

echo ""
echo "2. Configuración del sistema"
echo "----------------------------"
check_status "IP Forwarding habilitado" "[ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]"
check_status "WireGuard instalado" "which wg"
check_status "Configuración existe" "[ -f /etc/wireguard/wg0.conf ]"
check_status "Llaves del servidor existen" "[ -f /etc/wireguard/private.key ]"

echo ""
echo "3. Información del servidor"
echo "----------------------------"
SERVER_PUB_IP=$(curl -s ifconfig.me || echo "No disponible")
SERVER_PUB_KEY=$(cat /etc/wireguard/public.key 2>/dev/null || echo "No disponible")

echo "IP Pública: $SERVER_PUB_IP"
echo "Llave Pública: $SERVER_PUB_KEY"
echo "Puerto: 51820"

echo ""
echo "4. Interfaz de red WireGuard"
echo "----------------------------"
if ip addr show wg0 > /dev/null 2>&1; then
    ip addr show wg0 | grep -E "inet |mtu"
else
    echo -e "${RED}✗${NC} Interfaz wg0 no encontrada"
fi

echo ""
echo "5. Firewall"
echo "----------------------------"
if ufw status | grep -q "51820/udp"; then
    echo -e "${GREEN}✓${NC} Puerto 51820/UDP abierto"
    ufw status | grep 51820
else
    echo -e "${RED}✗${NC} Puerto 51820/UDP no está abierto"
    echo "Abre con: ufw allow 51820/udp"
fi

echo ""
echo "6. Reglas de NAT"
echo "----------------------------"
if iptables -t nat -L POSTROUTING -n | grep -q MASQUERADE; then
    echo -e "${GREEN}✓${NC} Regla MASQUERADE activa"
else
    echo -e "${YELLOW}⚠${NC} Regla MASQUERADE no encontrada"
fi

echo ""
echo "7. Clientes configurados"
echo "----------------------------"
CLIENTS_DIR=~/wireguard-clients
CLIENT_COUNT=$(ls -1 $CLIENTS_DIR/*.conf 2>/dev/null | wc -l)

if [ $CLIENT_COUNT -eq 0 ]; then
    echo "No hay clientes configurados todavía"
    echo "Agrega uno con: ./add-client.sh nombre"
else
    echo "Total de clientes: $CLIENT_COUNT"
    echo ""
    ls -1 $CLIENTS_DIR/*.conf 2>/dev/null | while read file; do
        CLIENT=$(basename "$file" .conf)
        CLIENT_IP=$(grep "Address" "$file" | awk '{print $3}' | cut -d'/' -f1)
        echo "  - $CLIENT ($CLIENT_IP)"
    done
fi

echo ""
echo "8. Clientes conectados actualmente"
echo "----------------------------"
if wg show wg0 peers 2>/dev/null | grep -q .; then
    wg show wg0 | grep -A 5 "peer:"
else
    echo "No hay clientes conectados actualmente"
fi

echo ""
echo "9. Estadísticas de tráfico"
echo "----------------------------"
if wg show wg0 transfer 2>/dev/null | grep -q .; then
    echo "Transferencia de datos:"
    wg show wg0 transfer
else
    echo "No hay datos de transferencia todavía"
fi

echo ""
echo "10. Logs recientes"
echo "----------------------------"
echo "Últimas 5 líneas del log:"
journalctl -u wg-quick@wg0 -n 5 --no-pager

echo ""
echo "========================================="
echo "Verificación completada"
echo "========================================="
echo ""
echo "💡 Comandos útiles:"
echo ""
echo "Ver estado en tiempo real:"
echo "  watch -n 1 wg show"
echo ""
echo "Ver logs en tiempo real:"
echo "  journalctl -u wg-quick@wg0 -f"
echo ""
echo "Reiniciar WireGuard:"
echo "  systemctl restart wg-quick@wg0"
echo ""
echo "Ver configuración activa:"
echo "  wg show wg0"
echo ""
echo "Gestión de clientes:"
echo "  ./add-client.sh nombre      # Agregar cliente"
echo "  ./remove-client.sh nombre   # Eliminar cliente"
echo "  ./list-clients.sh           # Listar todos"
echo ""

# Test de conectividad
echo "11. Test de conectividad"
echo "----------------------------"
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Conectividad a Internet funciona"
else
    echo -e "${RED}✗${NC} Sin conectividad a Internet"
fi

# Verificar DNS
if nslookup google.com > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Resolución DNS funciona"
else
    echo -e "${RED}✗${NC} Problemas con DNS"
fi

echo ""
