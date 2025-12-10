#!/bin/bash

# Script de deployment automático para VPC
# Uso: ./deploy.sh [servidor-ip] [dominio] [email]

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuración
SERVER_IP=${1:-""}
DOMAIN=${2:-""}
EMAIL=${3:-""}

if [ -z "$SERVER_IP" ] || [ -z "$DOMAIN" ]; then
    echo "Uso: ./deploy.sh SERVER_IP DOMAIN [EMAIL]"
    echo "Ejemplo: ./deploy.sh 1.2.3.4 ejemplo.com admin@ejemplo.com"
    exit 1
fi

if [ -z "$EMAIL" ]; then
    read -p "Email para Let's Encrypt: " EMAIL
fi

echo "========================================="
echo "Deployment automático de VPC"
echo "========================================="
echo ""
echo "Servidor: $SERVER_IP"
echo "Dominio: $DOMAIN"
echo "Email: $EMAIL"
echo ""

read -p "¿Continuar con el deployment? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Cancelado"
    exit 1
fi

# Verificar que tenemos acceso SSH
echo ""
echo "🔑 Verificando acceso SSH..."
if ! ssh -o ConnectTimeout=5 root@$SERVER_IP "echo 'SSH OK'" > /dev/null 2>&1; then
    echo "❌ No se puede conectar a root@$SERVER_IP"
    echo ""
    echo "Soluciones:"
    echo "  1. Verifica que la IP es correcta"
    echo "  2. Asegúrate de tener tu llave SSH configurada"
    echo "  3. Prueba manualmente: ssh root@$SERVER_IP"
    exit 1
fi
echo "✅ Acceso SSH verificado"

# Crear directorio en el servidor
echo ""
echo "📁 Preparando directorio en servidor..."
ssh root@$SERVER_IP "mkdir -p /root/vpc"

# Subir archivos (excluye .git, backups, etc.)
echo ""
echo "📤 Subiendo archivos al servidor..."
rsync -avz --progress \
    --exclude='.git' \
    --exclude='backups/' \
    --exclude='.env' \
    --exclude='*.gpg' \
    --exclude='.DS_Store' \
    ./ root@$SERVER_IP:/root/vpc/

echo "✅ Archivos subidos"

# Ejecutar instalación remota
echo ""
echo "========================================="
echo "🚀 Iniciando instalación en servidor"
echo "========================================="
echo ""

ssh -t root@$SERVER_IP "cd /root/vpc && bash -s" <<REMOTE_SCRIPT
    set -e

    echo ""
    echo "📋 Instalación de infraestructura VPC"
    echo ""

    # Hacer todos los scripts ejecutables
    find . -name "*.sh" -exec chmod +x {} \;

    # 1. SSH + Firewall
    echo ""
    echo "========================================="
    echo "Paso 1/4: Seguridad (SSH + Firewall)"
    echo "========================================="
    cd 01-ssh-firewall
    ./install.sh
    echo ""
    read -p "¿Ejecutar configuración de firewall? (s/N): " -n 1 -r
    echo ""
    if [[ \$REPLY =~ ^[Ss]$ ]]; then
        ./setup-firewall.sh
    fi
    cd ..

    # 2. Nginx + Let's Encrypt
    echo ""
    echo "========================================="
    echo "Paso 2/4: Nginx + SSL"
    echo "========================================="
    cd 02-nginx-letsencrypt
    ./install.sh
    echo ""
    read -p "¿Obtener certificado SSL para $DOMAIN? (s/N): " -n 1 -r
    echo ""
    if [[ \$REPLY =~ ^[Ss]$ ]]; then
        ./get-ssl-cert.sh $DOMAIN $EMAIL
    fi
    cd ..

    # 3. WireGuard VPN
    echo ""
    echo "========================================="
    echo "Paso 3/4: WireGuard VPN"
    echo "========================================="
    echo ""
    read -p "¿Instalar WireGuard VPN? (s/N): " -n 1 -r
    echo ""
    if [[ \$REPLY =~ ^[Ss]$ ]]; then
        cd 03-wireguard-vpn
        ./install.sh
        echo ""
        read -p "Nombre del primer cliente VPN: " CLIENT_NAME
        if [ ! -z "\$CLIENT_NAME" ]; then
            ./add-client.sh \$CLIENT_NAME
        fi
        cd ..
    fi

    # 4. Monitoreo
    echo ""
    echo "========================================="
    echo "Paso 4/4: Monitoreo"
    echo "========================================="
    echo ""
    echo "Opciones:"
    echo "  1) Netdata (recomendado, rápido)"
    echo "  2) Prometheus + Grafana (avanzado)"
    echo "  3) Solo monitoreo básico"
    echo "  4) Saltar monitoreo"
    echo ""
    read -p "Selecciona opción (1-4): " -n 1 MONITOR_OPT
    echo ""

    case \$MONITOR_OPT in
        1)
            cd 04-monitoring
            ./install-netdata.sh
            cd ..
            ;;
        2)
            cd 04-monitoring
            ./install-prometheus-grafana.sh
            cd ..
            ;;
        3)
            cd 04-monitoring
            ./setup-basic-monitoring.sh
            cd ..
            ;;
        *)
            echo "Saltando monitoreo..."
            ;;
    esac

    echo ""
    echo "========================================="
    echo "✅ Instalación completada"
    echo "========================================="
REMOTE_SCRIPT

# Resumen final
echo ""
echo "========================================="
echo "✅ DEPLOYMENT COMPLETADO"
echo "========================================="
echo ""
echo "🌐 Accesos:"
echo "  SSH:     ssh root@$SERVER_IP"
echo "  Web:     https://$DOMAIN"
echo "  Monitor: https://monitor.$DOMAIN (si instalaste Netdata)"
echo "  VPN:     Configs en /root/wireguard-clients/"
echo ""
echo "📋 Próximos pasos:"
echo "  1. Aplicar configuración SSH hardening (lee 01-ssh-firewall/README.md)"
echo "  2. Descargar configuraciones VPN si las creaste"
echo "  3. Hacer backup: ./backup-server.sh $SERVER_IP"
echo ""
echo "🔍 Verificar instalación:"
echo "  ssh root@$SERVER_IP 'cd /root/vpc && ./verify-all.sh'"
echo ""
