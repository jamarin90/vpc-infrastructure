#!/bin/bash

# Script de rollback - restaurar configuración anterior

set -e

echo "========================================="
echo "Rollback de Configuración SSH + Firewall"
echo "========================================="
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

echo "⚠️  Este script va a:"
echo "  - Restaurar configuración SSH original"
echo "  - Deshabilitar el firewall"
echo "  - Detener fail2ban (opcional)"
echo ""
read -p "¿Continuar con el rollback? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Cancelado"
    exit 1
fi

# Restaurar SSH
if [ -f "/etc/ssh/sshd_config.backup" ]; then
    echo "📋 Restaurando configuración SSH original..."
    cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config

    # Verificar configuración
    if sshd -t; then
        echo "✓ Configuración SSH válida"
        systemctl restart sshd
        echo "✓ SSH reiniciado"
    else
        echo "❌ Error en configuración SSH"
        exit 1
    fi
else
    echo "⚠️  No se encontró backup de SSH (/etc/ssh/sshd_config.backup)"
fi

# Deshabilitar firewall
echo ""
echo "🛡️  Deshabilitando firewall..."
ufw --force disable
echo "✓ Firewall deshabilitado"

# Preguntar por fail2ban
echo ""
read -p "¿Detener fail2ban también? (s/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    systemctl stop fail2ban
    systemctl disable fail2ban
    echo "✓ Fail2ban detenido y deshabilitado"
fi

echo ""
echo "✅ Rollback completado"
echo ""
echo "Estado actual:"
echo "  - SSH: restaurado a configuración original"
echo "  - Firewall: deshabilitado"
echo ""
