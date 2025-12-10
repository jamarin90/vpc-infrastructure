#!/bin/bash

# Script de verificación de seguridad SSH + Firewall

echo "========================================="
echo "Verificación de Seguridad"
echo "========================================="
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_service() {
    local service=$1
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✓${NC} $service está activo"
        return 0
    else
        echo -e "${RED}✗${NC} $service NO está activo"
        return 1
    fi
}

echo "1. Verificando servicios..."
echo "----------------------------"
check_service ssh
check_service fail2ban
check_service ufw

echo ""
echo "2. Estado del Firewall"
echo "----------------------------"
ufw status numbered

echo ""
echo "3. Estado de Fail2ban"
echo "----------------------------"
fail2ban-client status

echo ""
echo "4. Estadísticas SSH de Fail2ban"
echo "----------------------------"
fail2ban-client status sshd 2>/dev/null || echo "Jail sshd no activo aún"

echo ""
echo "5. Configuración SSH"
echo "----------------------------"
echo "Puerto SSH:"
grep "^Port" /etc/ssh/sshd_config || echo "Puerto por defecto (22)"

echo ""
echo "Autenticación con password:"
grep "^PasswordAuthentication" /etc/ssh/sshd_config

echo ""
echo "Login de root:"
grep "^PermitRootLogin" /etc/ssh/sshd_config

echo ""
echo "6. Últimos intentos de login"
echo "----------------------------"
echo "Últimos 10 intentos de autenticación:"
tail -n 10 /var/log/auth.log | grep -i "sshd"

echo ""
echo "7. IPs actualmente baneadas"
echo "----------------------------"
fail2ban-client status sshd 2>/dev/null | grep "Banned IP" || echo "Sin IPs baneadas aún"

echo ""
echo "8. Puertos abiertos"
echo "----------------------------"
ss -tulpn | grep LISTEN

echo ""
echo "========================================="
echo "Verificación completada"
echo "========================================="
echo ""
echo "💡 Comandos útiles:"
echo "  - Ver logs SSH en tiempo real: tail -f /var/log/auth.log"
echo "  - Ver logs fail2ban: tail -f /var/log/fail2ban.log"
echo "  - Ver logs firewall: tail -f /var/log/ufw.log"
echo "  - Desbanear una IP: fail2ban-client set sshd unbanip IP_AQUI"
echo ""
