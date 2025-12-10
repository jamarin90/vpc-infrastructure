#!/bin/bash

# Script para obtener certificado SSL de Let's Encrypt
# Uso: ./get-ssl-cert.sh tu-dominio.com tu-email@ejemplo.com

set -e

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

# Verificar argumentos
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <dominio> <email>"
    echo "Ejemplo: $0 ejemplo.com admin@ejemplo.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

echo "========================================="
echo "Obtención de certificado SSL"
echo "========================================="
echo ""
echo "Dominio: $DOMAIN"
echo "Email: $EMAIL"
echo ""

# Verificar que Nginx está corriendo
if ! systemctl is-active --quiet nginx; then
    echo "❌ Nginx no está corriendo. Ejecuta ./install.sh primero"
    exit 1
fi

# Verificar que el dominio apunta al servidor
echo "🔍 Verificando DNS..."
SERVER_IP=$(hostname -I | awk '{print $1}')
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)

if [ -z "$DOMAIN_IP" ]; then
    echo "⚠️  Advertencia: No se pudo resolver el dominio $DOMAIN"
    read -p "¿Continuar de todas formas? (s/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
elif [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo "⚠️  Advertencia: El dominio apunta a $DOMAIN_IP pero el servidor es $SERVER_IP"
    read -p "¿Continuar de todas formas? (s/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
else
    echo "✅ El dominio apunta correctamente a este servidor"
fi

# Crear configuración básica de Nginx para el dominio si no existe
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
if [ ! -f "$NGINX_CONFIG" ]; then
    echo ""
    echo "📝 Creando configuración básica de Nginx..."
    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/$DOMAIN;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Let's Encrypt challenge
    location ~ /.well-known/acme-challenge {
        allow all;
        root /var/www/$DOMAIN;
    }
}
EOF

    # Crear directorio web
    mkdir -p /var/www/$DOMAIN

    # Crear página de prueba
    cat > /var/www/$DOMAIN/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>$DOMAIN</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
        }
        h1 { font-size: 3em; margin: 0; }
        p { font-size: 1.2em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 $DOMAIN</h1>
        <p>Servidor funcionando correctamente</p>
        <p><small>Nginx + Let's Encrypt</small></p>
    </div>
</body>
</html>
EOF

    # Habilitar sitio
    ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

    # Probar configuración
    nginx -t

    # Recargar Nginx
    systemctl reload nginx

    echo "✅ Sitio configurado en /var/www/$DOMAIN"
fi

# Obtener certificado SSL
echo ""
echo "🔒 Obteniendo certificado SSL de Let's Encrypt..."
echo ""

# Usar certbot con plugin de Nginx
certbot --nginx \
    -d $DOMAIN \
    -d www.$DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --redirect

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ¡Certificado SSL instalado correctamente!"
    echo ""
    echo "📊 Información del certificado:"
    certbot certificates -d $DOMAIN
    echo ""
    echo "🌐 Prueba tu sitio:"
    echo "   https://$DOMAIN"
    echo "   https://www.$DOMAIN"
    echo ""
    echo "🔄 Renovación automática:"
    echo "   Los certificados se renovarán automáticamente cada 60 días"
    echo "   Verificar: systemctl status certbot.timer"
    echo ""
    echo "🔍 Verificar seguridad SSL:"
    echo "   https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
    echo ""
else
    echo ""
    echo "❌ Error al obtener el certificado"
    echo "Ver logs: /var/log/letsencrypt/letsencrypt.log"
    echo ""
    echo "Posibles causas:"
    echo "  - El dominio no apunta al servidor"
    echo "  - Puertos 80/443 no están accesibles"
    echo "  - Límite de tasa de Let's Encrypt alcanzado"
    exit 1
fi

# Crear snippet de parámetros SSL si no existe
SSL_PARAMS="/etc/nginx/snippets/ssl-params.conf"
if [ ! -f "$SSL_PARAMS" ]; then
    echo "📝 Creando configuración SSL optimizada..."
    cat > $SSL_PARAMS <<'EOF'
# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;

# Security headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;

# Diffie-Hellman parameter
ssl_dhparam /etc/nginx/dhparam.pem;
EOF

    # Generar parámetros Diffie-Hellman (puede tomar unos minutos)
    if [ ! -f "/etc/nginx/dhparam.pem" ]; then
        echo "🔐 Generando parámetros Diffie-Hellman (esto puede tomar unos minutos)..."
        openssl dhparam -out /etc/nginx/dhparam.pem 2048
    fi

    echo "✅ Configuración SSL optimizada creada"
fi

echo ""
echo "========================================="
echo "✅ Proceso completado"
echo "========================================="
