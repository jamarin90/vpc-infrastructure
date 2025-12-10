#!/bin/bash

# Script de verificación de Nginx + Let's Encrypt

echo "========================================="
echo "Verificación de Nginx + Let's Encrypt"
echo "========================================="
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
check_service nginx
check_service certbot.timer

echo ""
echo "2. Versiones instaladas"
echo "----------------------------"
echo "Nginx: $(nginx -v 2>&1 | grep -oP '(?<=nginx/)[0-9.]+')"
echo "Certbot: $(certbot --version 2>&1 | grep -oP '[0-9.]+')"

echo ""
echo "3. Certificados instalados"
echo "----------------------------"
certbot certificates 2>/dev/null || echo "No hay certificados instalados todavía"

echo ""
echo "4. Sitios configurados"
echo "----------------------------"
echo "Sitios disponibles:"
ls -1 /etc/nginx/sites-available/ | grep -v default
echo ""
echo "Sitios habilitados:"
ls -1 /etc/nginx/sites-enabled/ | grep -v default

echo ""
echo "5. Puertos en escucha"
echo "----------------------------"
ss -tulpn | grep nginx

echo ""
echo "6. Configuración de Nginx"
echo "----------------------------"
if nginx -t 2>&1; then
    echo -e "${GREEN}✓${NC} Configuración válida"
else
    echo -e "${RED}✗${NC} Configuración con errores"
fi

echo ""
echo "7. Estado de renovación automática"
echo "----------------------------"
systemctl status certbot.timer --no-pager | grep -E "Active|Trigger"

echo ""
echo "8. Test de renovación (dry-run)"
echo "----------------------------"
echo "Ejecutando simulación de renovación..."
certbot renew --dry-run 2>&1 | tail -n 5

echo ""
echo "9. Últimos accesos"
echo "----------------------------"
if [ -f /var/log/nginx/access.log ]; then
    echo "Últimas 5 peticiones:"
    tail -n 5 /var/log/nginx/access.log
else
    echo "No hay logs de acceso todavía"
fi

echo ""
echo "10. Errores recientes"
echo "----------------------------"
if [ -f /var/log/nginx/error.log ]; then
    ERRORS=$(tail -n 20 /var/log/nginx/error.log | wc -l)
    if [ $ERRORS -gt 0 ]; then
        echo "Últimos errores:"
        tail -n 5 /var/log/nginx/error.log
    else
        echo -e "${GREEN}✓${NC} Sin errores recientes"
    fi
else
    echo "No hay logs de error"
fi

echo ""
echo "========================================="
echo "Verificación completada"
echo "========================================="
echo ""
echo "💡 Comandos útiles:"
echo "  - Ver logs en tiempo real:"
echo "    tail -f /var/log/nginx/access.log"
echo "    tail -f /var/log/nginx/error.log"
echo ""
echo "  - Renovar certificados manualmente:"
echo "    certbot renew"
echo ""
echo "  - Ver info de un certificado:"
echo "    certbot certificates -d tu-dominio.com"
echo ""
echo "  - Revocar un certificado:"
echo "    certbot revoke --cert-name tu-dominio.com"
echo ""
echo "  - Recargar configuración Nginx:"
echo "    nginx -t && systemctl reload nginx"
echo ""
