#!/bin/bash

# Script para actualizar servidor con últimos cambios

set -e

SERVER_IP=${1:-""}
if [ -z "$SERVER_IP" ]; then
    echo "Uso: ./update-server.sh SERVER_IP"
    echo "Ejemplo: ./update-server.sh 1.2.3.4"
    exit 1
fi

echo "========================================="
echo "Actualización del servidor"
echo "========================================="
echo ""

# Verificar si estamos en un repo git
if [ ! -d .git ]; then
    echo "⚠️  Advertencia: No estás en un repositorio Git"
    echo "Continuando de todas formas..."
else
    # Pull últimos cambios si es un repo
    echo "📥 Descargando últimos cambios..."
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "Sin cambios remotos"
    echo "✅ Repositorio actualizado"
fi

# Verificar acceso SSH
echo ""
echo "🔑 Verificando acceso al servidor..."
if ! ssh -o ConnectTimeout=5 root@$SERVER_IP "echo 'OK'" > /dev/null 2>&1; then
    echo "❌ No se puede conectar a root@$SERVER_IP"
    exit 1
fi
echo "✅ Acceso verificado"

# Hacer backup antes de actualizar
echo ""
read -p "¿Hacer backup antes de actualizar? (S/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "📦 Creando backup..."
    ./backup-server.sh $SERVER_IP
fi

# Subir archivos actualizados
echo ""
echo "📤 Subiendo archivos actualizados..."
rsync -avz --progress \
    --exclude='.git' \
    --exclude='backups/' \
    --exclude='.env' \
    --exclude='*.gpg' \
    --exclude='.DS_Store' \
    ./ root@$SERVER_IP:/root/vpc/

echo "✅ Archivos sincronizados"

# Hacer scripts ejecutables
echo ""
echo "🔧 Configurando permisos..."
ssh root@$SERVER_IP "cd /root/vpc && find . -name '*.sh' -exec chmod +x {} \;"

echo ""
echo "========================================="
echo "¿Qué servicios necesitan reiniciarse?"
echo "========================================="
echo ""
echo "1) Nginx"
echo "2) WireGuard VPN"
echo "3) Netdata"
echo "4) Monitoreo (Docker)"
echo "5) Todo"
echo "6) Ninguno (solo actualizar archivos)"
echo ""
read -p "Selecciona opción (1-6): " RESTART_OPT

case $RESTART_OPT in
    1)
        echo "🔄 Reiniciando Nginx..."
        ssh root@$SERVER_IP "nginx -t && systemctl reload nginx"
        ;;
    2)
        echo "🔄 Reiniciando WireGuard..."
        ssh root@$SERVER_IP "systemctl restart wg-quick@wg0"
        ;;
    3)
        echo "🔄 Reiniciando Netdata..."
        ssh root@$SERVER_IP "systemctl restart netdata"
        ;;
    4)
        echo "🔄 Reiniciando contenedores de monitoreo..."
        ssh root@$SERVER_IP "cd /opt/monitoring && docker-compose restart"
        ;;
    5)
        echo "🔄 Reiniciando todos los servicios..."
        ssh root@$SERVER_IP "
            nginx -t && systemctl reload nginx
            systemctl restart wg-quick@wg0 2>/dev/null || true
            systemctl restart netdata 2>/dev/null || true
            cd /opt/monitoring && docker-compose restart 2>/dev/null || true
        "
        ;;
    *)
        echo "⏭️  No se reiniciaron servicios"
        ;;
esac

# Verificar servicios
echo ""
echo "🔍 Verificando estado de servicios..."
ssh root@$SERVER_IP "cd /root/vpc && bash -s" <<'VERIFY_SCRIPT'
    echo ""
    echo "Estado de servicios:"
    echo "-------------------"

    # SSH
    if systemctl is-active --quiet ssh; then
        echo "✅ SSH"
    else
        echo "❌ SSH"
    fi

    # Nginx
    if systemctl is-active --quiet nginx; then
        echo "✅ Nginx"
    else
        echo "❌ Nginx"
    fi

    # fail2ban
    if systemctl is-active --quiet fail2ban; then
        echo "✅ fail2ban"
    else
        echo "⚠️  fail2ban"
    fi

    # WireGuard
    if systemctl is-active --quiet wg-quick@wg0; then
        echo "✅ WireGuard VPN"
    else
        echo "⚠️  WireGuard VPN (puede no estar instalado)"
    fi

    # Netdata
    if systemctl is-active --quiet netdata; then
        echo "✅ Netdata"
    else
        echo "⚠️  Netdata (puede no estar instalado)"
    fi

    # Docker
    if command -v docker &> /dev/null; then
        CONTAINERS=$(docker ps -q | wc -l)
        echo "✅ Docker ($CONTAINERS contenedores corriendo)"
    fi

    echo ""
VERIFY_SCRIPT

echo ""
echo "========================================="
echo "✅ Actualización completada"
echo "========================================="
echo ""
echo "📋 Acciones realizadas:"
echo "  - Archivos sincronizados"
echo "  - Permisos actualizados"
echo "  - Servicios verificados"
echo ""
echo "💡 Próximos pasos:"
echo "  - Verificar sitio web funciona: https://tu-dominio.com"
echo "  - Probar VPN si la usas"
echo "  - Revisar monitoreo"
echo ""
echo "🔍 Ver logs si hay problemas:"
echo "  ssh root@$SERVER_IP 'journalctl -xe'"
echo "  ssh root@$SERVER_IP 'tail -f /var/log/nginx/error.log'"
echo ""
