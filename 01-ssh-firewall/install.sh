#!/bin/bash

# Script de instalación para seguridad SSH + Firewall
# Para Debian/Ubuntu

set -e  # Salir si hay error

echo "========================================="
echo "Instalación de Seguridad SSH + Firewall"
echo "========================================="
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

# Actualizar sistema
echo "📦 Actualizando sistema..."
apt-get update
apt-get upgrade -y

# Instalar fail2ban
echo ""
echo "🔒 Instalando fail2ban..."
apt-get install -y fail2ban

# Instalar ufw
echo ""
echo "🛡️  Instalando ufw (firewall)..."
apt-get install -y ufw

# Configurar fail2ban
echo ""
echo "⚙️  Configurando fail2ban..."

# Copiar configuración personalizada
if [ -f "jail.local" ]; then
    cp jail.local /etc/fail2ban/jail.local
    echo "✓ Configuración jail.local copiada"
else
    echo "⚠️  Advertencia: jail.local no encontrado, usando configuración por defecto"
fi

# Reiniciar y habilitar fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

echo ""
echo "✅ Instalación completada"
echo ""
echo "📋 Próximos pasos:"
echo "1. Edita setup-firewall.sh si necesitas personalizar puertos"
echo "2. Ejecuta ./setup-firewall.sh"
echo "3. Aplica la configuración SSH (lee el README.md)"
echo ""
echo "🔍 Verificar instalación:"
echo "  systemctl status fail2ban"
echo "  fail2ban-client status"
echo ""
