#!/bin/bash

# Script de instalación de Nginx + Let's Encrypt (Certbot)
# Para Debian/Ubuntu

set -e

echo "========================================="
echo "Instalación de Nginx + Let's Encrypt"
echo "========================================="
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

# Actualizar repositorios
echo "📦 Actualizando repositorios..."
apt-get update

# Instalar Nginx
echo ""
echo "🌐 Instalando Nginx..."
apt-get install -y nginx

# Instalar Certbot y plugin de Nginx
echo ""
echo "🔒 Instalando Certbot (cliente Let's Encrypt)..."
apt-get install -y certbot python3-certbot-nginx

# Habilitar y arrancar Nginx
echo ""
echo "🚀 Habilitando Nginx..."
systemctl enable nginx
systemctl start nginx

# Verificar que Nginx está corriendo
if systemctl is-active --quiet nginx; then
    echo "✅ Nginx instalado y corriendo correctamente"
else
    echo "❌ Error: Nginx no está corriendo"
    exit 1
fi

# Crear directorio para snippets si no existe
mkdir -p /etc/nginx/snippets

# Configurar renovación automática de certificados
echo ""
echo "⚙️  Configurando renovación automática de certificados..."

# Habilitar timer de certbot para renovación automática
systemctl enable certbot.timer
systemctl start certbot.timer

echo ""
echo "✅ Instalación completada"
echo ""
echo "📊 Estado de servicios:"
systemctl status nginx --no-pager -l
echo ""
systemctl status certbot.timer --no-pager -l

echo ""
echo "📋 Próximos pasos:"
echo ""
echo "1. Verifica que tu dominio apunta a este servidor:"
echo "   dig tu-dominio.com +short"
echo ""
echo "2. Obtén un certificado SSL:"
echo "   ./get-ssl-cert.sh tu-dominio.com tu-email@ejemplo.com"
echo ""
echo "3. Prueba que funciona:"
echo "   curl http://$(hostname -I | awk '{print $1}')"
echo "   curl https://tu-dominio.com"
echo ""
echo "💡 Tips:"
echo "  - Configuraciones de sitios: /etc/nginx/sites-available/"
echo "  - Sitios activos: /etc/nginx/sites-enabled/"
echo "  - Logs: /var/log/nginx/"
echo "  - Probar configuración: nginx -t"
echo "  - Recargar configuración: systemctl reload nginx"
echo ""
