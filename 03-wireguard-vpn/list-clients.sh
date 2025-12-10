#!/bin/bash

# Script para listar todos los clientes de WireGuard

echo "========================================="
echo "Clientes de WireGuard"
echo "========================================="
echo ""

CLIENTS_DIR=~/wireguard-clients

# Verificar que el directorio existe
if [ ! -d "$CLIENTS_DIR" ]; then
    echo "❌ No se encontró el directorio de clientes"
    echo "¿WireGuard está instalado?"
    exit 1
fi

# Contar clientes
CLIENT_COUNT=$(ls -1 $CLIENTS_DIR/*.conf 2>/dev/null | wc -l)

if [ $CLIENT_COUNT -eq 0 ]; then
    echo "No hay clientes configurados todavía"
    echo ""
    echo "Agrega tu primer cliente con:"
    echo "  ./add-client.sh nombre-cliente"
    exit 0
fi

echo "Total de clientes configurados: $CLIENT_COUNT"
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Obtener lista de peers conectados
CONNECTED_PEERS=$(wg show wg0 peers 2>/dev/null || echo "")

echo "┌─────────────────────────────────────────────────────────────────┐"
printf "│ %-15s │ %-15s │ %-20s │\n" "Cliente" "IP VPN" "Estado"
echo "├─────────────────────────────────────────────────────────────────┤"

# Listar cada cliente
ls -1 $CLIENTS_DIR/*.conf 2>/dev/null | sort | while read file; do
    CLIENT=$(basename "$file" .conf)
    CLIENT_IP=$(grep "Address" "$file" | awk '{print $3}' | cut -d'/' -f1 2>/dev/null || echo "N/A")

    # Obtener llave pública del cliente para verificar si está conectado
    if [ -f "$CLIENTS_DIR/$CLIENT.txt" ]; then
        CLIENT_PUB_KEY=$(grep "Llave pública:" "$CLIENTS_DIR/$CLIENT.txt" | cut -d' ' -f3 2>/dev/null)
    else
        CLIENT_PUB_KEY=""
    fi

    # Verificar si está conectado
    if echo "$CONNECTED_PEERS" | grep -q "$CLIENT_PUB_KEY" 2>/dev/null; then
        STATUS="${GREEN}Conectado${NC}"
    else
        STATUS="${YELLOW}Desconectado${NC}"
    fi

    printf "│ %-15s │ %-15s │ " "$CLIENT" "$CLIENT_IP"
    echo -e "$STATUS                │"
done

echo "└─────────────────────────────────────────────────────────────────┘"
echo ""

# Mostrar detalles de clientes conectados
echo "📊 Clientes conectados ahora:"
echo "----------------------------"

if [ -n "$CONNECTED_PEERS" ]; then
    wg show wg0 | grep -A 6 "peer:" | while IFS= read -r line; do
        if [[ $line == peer:* ]]; then
            PEER_KEY=$(echo $line | awk '{print $2}')
            # Buscar nombre del cliente por su llave pública
            for file in $CLIENTS_DIR/*.txt; do
                if grep -q "$PEER_KEY" "$file" 2>/dev/null; then
                    CLIENT=$(basename "$file" .txt)
                    echo -e "\n${BLUE}Cliente: $CLIENT${NC}"
                    break
                fi
            done
        fi
        echo "$line"
    done
else
    echo "No hay clientes conectados actualmente"
fi

echo ""
echo "📁 Archivos de configuración:"
echo "----------------------------"
ls -lh $CLIENTS_DIR/*.conf 2>/dev/null | awk '{print $9, "(" $5 ")"}'

# Mostrar clientes eliminados si existen
if [ -d "$CLIENTS_DIR/deleted" ]; then
    DELETED_COUNT=$(ls -1 $CLIENTS_DIR/deleted/*.conf 2>/dev/null | wc -l)
    if [ $DELETED_COUNT -gt 0 ]; then
        echo ""
        echo "🗑️  Clientes eliminados: $DELETED_COUNT"
        ls -1 $CLIENTS_DIR/deleted/*.conf 2>/dev/null | xargs -n 1 basename | sed 's/.conf$//'
    fi
fi

echo ""
echo "💡 Comandos útiles:"
echo "  ./add-client.sh nombre       # Agregar nuevo cliente"
echo "  ./remove-client.sh nombre    # Eliminar cliente"
echo "  wg show                      # Ver estado detallado"
echo "  wg show wg0 transfer         # Ver tráfico de datos"
echo ""
