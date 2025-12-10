#!/bin/bash

# Script de configuración del firewall (ufw)

set -e

echo "========================================="
echo "Configuración del Firewall (ufw)"
echo "========================================="
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

echo "⚠️  ADVERTENCIA:"
echo "Este script va a configurar el firewall."
echo "Asegúrate de tener una sesión SSH activa antes de continuar."
echo ""
read -p "¿Continuar? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Cancelado"
    exit 1
fi

echo ""
echo "🛡️  Configurando firewall..."

# Reset ufw (limpia reglas previas)
ufw --force reset

# Políticas por defecto
ufw default deny incoming
ufw default allow outgoing

# Permitir SSH (puerto 22)
# ⚠️ Si cambiaste el puerto SSH, modifica aquí
ufw allow 22/tcp comment 'SSH'

# Permitir HTTP y HTTPS (para futuros servicios web)
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# OPCIONAL: Restringir SSH solo a tu IP
# Descomenta y reemplaza TU_IP_AQUI con tu IP
# ufw delete allow 22/tcp
# ufw allow from TU_IP_AQUI to any port 22 comment 'SSH desde IP específica'

# OPCIONAL: Si vas a usar WireGuard (puerto 51820 UDP)
# Descomenta cuando instales WireGuard
# ufw allow 51820/udp comment 'WireGuard VPN'

# Habilitar firewall
echo ""
echo "🔥 Activando firewall..."
ufw --force enable

echo ""
echo "✅ Firewall configurado correctamente"
echo ""
echo "📊 Estado actual:"
ufw status verbose

echo ""
echo "✓ Reglas activas:"
echo "  - SSH (puerto 22)"
echo "  - HTTP (puerto 80)"
echo "  - HTTPS (puerto 443)"
echo ""
echo "💡 Tip: Para ver logs del firewall:"
echo "   tail -f /var/log/ufw.log"
echo ""
