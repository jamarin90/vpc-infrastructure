#!/bin/bash

# Script de instalación de Netdata
# Dashboard de monitoreo en tiempo real, simple y potente

set -e

echo "========================================="
echo "Instalación de Netdata"
echo "========================================="
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

# Detectar IP pública
SERVER_IP=$(curl -s ifconfig.me)
echo "📍 IP del servidor: $SERVER_IP"
echo ""

# Preguntar por el dominio
read -p "¿Quieres acceder a Netdata por dominio? (s/N): " -n 1 -r
echo ""

USE_DOMAIN=false
if [[ $REPLY =~ ^[Ss]$ ]]; then
    USE_DOMAIN=true
    read -p "Ingresa el dominio (ej: monitor.tu-dominio.com): " DOMAIN
    echo ""
fi

# Confirmar instalación
echo "Se instalará Netdata con la siguiente configuración:"
echo "  - Puerto local: 19999"
if [ "$USE_DOMAIN" = true ]; then
    echo "  - Dominio: https://$DOMAIN"
    echo "  - SSL: Let's Encrypt"
    echo "  - Autenticación: Usuario y contraseña"
else
    echo "  - Acceso: http://$SERVER_IP:19999"
    echo "  - Acceso VPN: http://10.8.0.1:19999"
fi
echo ""

read -p "¿Continuar? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Instalación cancelada"
    exit 1
fi

# Instalar dependencias
echo ""
echo "📦 Instalando dependencias..."
apt-get update
apt-get install -y curl wget

# Instalar Netdata con script oficial
echo ""
echo "🚀 Instalando Netdata..."
echo ""
echo "Esto puede tomar unos minutos..."

# Descargar e instalar
bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait

# Verificar que se instaló
if ! systemctl is-active --quiet netdata; then
    echo "❌ Error: Netdata no se instaló correctamente"
    exit 1
fi

echo ""
echo "✅ Netdata instalado correctamente"

# Configurar para bind solo a localhost (si usaremos Nginx)
if [ "$USE_DOMAIN" = true ]; then
    echo ""
    echo "⚙️  Configurando Netdata para acceso via Nginx..."

    # Configurar bind a localhost solo
    sed -i 's/bind to = \*/bind to = 127.0.0.1/' /etc/netdata/netdata.conf 2>/dev/null || \
        echo -e "[web]\n\tbind to = 127.0.0.1" >> /etc/netdata/netdata.conf

    # Reiniciar Netdata
    systemctl restart netdata

    # Configurar Nginx
    echo ""
    echo "🌐 Configurando Nginx reverse proxy..."

    # Crear configuración de Nginx
    cat > /etc/nginx/sites-available/netdata.conf <<EOF
upstream netdata {
    server 127.0.0.1:19999;
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Redirigir HTTP a HTTPS (después de obtener certificado)
    # return 301 https://\$server_name\$request_uri;

    # Temporal para Let's Encrypt
    location / {
        proxy_pass http://netdata;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    # Habilitar sitio
    ln -sf /etc/nginx/sites-available/netdata.conf /etc/nginx/sites-enabled/

    # Probar configuración
    nginx -t

    # Recargar Nginx
    systemctl reload nginx

    # Obtener certificado SSL
    echo ""
    echo "🔒 Obteniendo certificado SSL..."
    read -p "Ingresa tu email para Let's Encrypt: " EMAIL

    certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

    # Configurar autenticación básica
    echo ""
    echo "🔐 Configurando autenticación..."
    apt-get install -y apache2-utils

    read -p "Usuario para acceso a Netdata: " NETDATA_USER
    htpasswd -c /etc/nginx/.htpasswd-netdata $NETDATA_USER

    # Actualizar configuración Nginx con auth
    cat > /etc/nginx/sites-available/netdata.conf <<EOF
upstream netdata {
    server 127.0.0.1:19999;
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include snippets/ssl-params.conf;

    access_log /var/log/nginx/netdata-access.log;
    error_log /var/log/nginx/netdata-error.log;

    # Autenticación básica
    auth_basic "Netdata Monitoring";
    auth_basic_user_file /etc/nginx/.htpasswd-netdata;

    location / {
        proxy_pass http://netdata;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    nginx -t && systemctl reload nginx
fi

# Configurar actualizaciones automáticas
echo ""
echo "⚙️  Configurando actualizaciones automáticas..."
cat > /etc/cron.daily/netdata-updater <<'EOF'
#!/bin/bash
/usr/libexec/netdata/netdata-updater.sh --not-running-from-cron
EOF
chmod +x /etc/cron.daily/netdata-updater

# Optimizar configuración de Netdata
echo ""
echo "⚙️  Optimizando configuración..."

# Crear archivo de configuración personalizado si no existe
if [ ! -f /etc/netdata/netdata.conf ]; then
    /usr/sbin/netdata -W set 2>&1 | grep "# " > /etc/netdata/netdata.conf
fi

# Ajustar retención de datos (1 día en vez de 1 hora por defecto)
cat >> /etc/netdata/netdata.conf <<EOF

[global]
    memory mode = dbengine
    page cache size = 32
    dbengine disk space = 256

[web]
    web files owner = root
    web files group = netdata
EOF

# Reiniciar Netdata con nueva configuración
systemctl restart netdata

# Esperar a que arranque
sleep 3

# Verificar que está corriendo
if systemctl is-active --quiet netdata; then
    echo ""
    echo "========================================="
    echo "✅ Instalación completada"
    echo "========================================="
    echo ""

    if [ "$USE_DOMAIN" = true ]; then
        echo "🌐 Acceso web:"
        echo "   https://$DOMAIN"
        echo ""
        echo "🔐 Credenciales:"
        echo "   Usuario: $NETDATA_USER"
        echo "   Contraseña: (la que ingresaste)"
    else
        echo "🌐 Acceso web:"
        echo "   http://$SERVER_IP:19999"
        echo "   http://10.8.0.1:19999 (desde VPN)"
        echo ""
        echo "⚠️  Para acceso seguro con SSL, ejecuta:"
        echo "   ./install-netdata.sh"
        echo "   y configura un dominio"
    fi

    echo ""
    echo "📊 Características activadas:"
    echo "   ✓ Monitoreo en tiempo real"
    echo "   ✓ Dashboard interactivo"
    echo "   ✓ Alertas automáticas"
    echo "   ✓ Retención de datos: 1 día"
    echo "   ✓ Actualización automática diaria"

    if systemctl is-active --quiet docker; then
        echo "   ✓ Monitoreo de Docker containers"
    fi

    if systemctl is-active --quiet nginx; then
        echo "   ✓ Monitoreo de Nginx"
    fi

    echo ""
    echo "🔧 Gestión de Netdata:"
    echo "   systemctl status netdata"
    echo "   systemctl restart netdata"
    echo "   journalctl -u netdata -f"
    echo ""
    echo "📁 Archivos de configuración:"
    echo "   /etc/netdata/netdata.conf"
    echo "   /etc/netdata/health.d/         (alertas)"
    echo ""
    echo "💡 Personalización:"
    echo "   - Edita /etc/netdata/netdata.conf"
    echo "   - Configura alertas en /etc/netdata/health.d/"
    echo "   - Deshabilita plugins en /etc/netdata/python.d.conf"
    echo ""
    echo "🎉 ¡Disfruta de Netdata!"
    echo ""
else
    echo ""
    echo "❌ Error: Netdata no está corriendo"
    echo "Ver logs: journalctl -u netdata -n 50"
    exit 1
fi

# Abrir puerto en firewall si no se usa dominio
if [ "$USE_DOMAIN" = false ]; then
    echo "🛡️  Abriendo puerto 19999 en el firewall..."
    ufw allow 19999/tcp comment 'Netdata monitoring'
    echo "✓ Puerto 19999 abierto"
    echo ""
fi

echo "========================================="
