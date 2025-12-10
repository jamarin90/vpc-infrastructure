#!/bin/bash

# Script para obtener certificado SSL Wildcard de Let's Encrypt
# Uso: ./get-wildcard-cert.sh tu-dominio.com tu-email@ejemplo.com [dns-provider]
#
# Los certificados wildcard requieren validación DNS (DNS-01 challenge)
# Opciones de validación:
#   1. Manual: Se te pedirá crear un registro TXT en tu DNS
#   2. Automático: Usando plugins de Certbot para proveedores DNS (Cloudflare, DigitalOcean, etc.)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script debe ejecutarse como root${NC}"
    exit 1
fi

# Verificar argumentos mínimos
if [ "$#" -lt 2 ]; then
    echo "Uso: $0 <dominio> <email> [dns-provider]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 ejemplo.com admin@ejemplo.com           # Validación DNS manual"
    echo "  $0 ejemplo.com admin@ejemplo.com cloudflare # Usando Cloudflare DNS"
    echo "  $0 ejemplo.com admin@ejemplo.com digitalocean # Usando DigitalOcean DNS"
    echo ""
    echo "Proveedores DNS soportados:"
    echo "  - cloudflare    (requiere API token)"
    echo "  - digitalocean  (requiere API token)"
    echo "  - route53       (requiere AWS credentials)"
    echo "  - google        (requiere service account)"
    echo "  - manual        (crear registro TXT manualmente)"
    exit 1
fi

DOMAIN=$1
EMAIL=$2
DNS_PROVIDER=${3:-manual}

echo "========================================="
echo "Certificado Wildcard SSL"
echo "========================================="
echo ""
echo -e "Dominio:    ${BLUE}$DOMAIN${NC}"
echo -e "Wildcard:   ${BLUE}*.$DOMAIN${NC}"
echo -e "Email:      ${BLUE}$EMAIL${NC}"
echo -e "Proveedor:  ${BLUE}$DNS_PROVIDER${NC}"
echo ""

# Función para instalar plugin de DNS
install_dns_plugin() {
    local provider=$1
    local package=""

    case $provider in
        cloudflare)
            package="python3-certbot-dns-cloudflare"
            ;;
        digitalocean)
            package="python3-certbot-dns-digitalocean"
            ;;
        route53)
            package="python3-certbot-dns-route53"
            ;;
        google)
            package="python3-certbot-dns-google"
            ;;
        *)
            return 0
            ;;
    esac

    if ! dpkg -l | grep -q "$package"; then
        echo -e "${YELLOW}Instalando plugin $package...${NC}"
        apt-get update
        apt-get install -y $package
    fi
}

# Función para configurar credenciales de Cloudflare
setup_cloudflare() {
    CREDENTIALS_FILE="/etc/letsencrypt/cloudflare.ini"

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        echo ""
        echo -e "${YELLOW}Configuración de Cloudflare${NC}"
        echo "Necesitas un API Token de Cloudflare con permisos:"
        echo "  - Zone:DNS:Edit"
        echo ""
        echo "Obtén tu token en: https://dash.cloudflare.com/profile/api-tokens"
        echo ""
        read -p "Ingresa tu Cloudflare API Token: " CF_TOKEN

        if [ -z "$CF_TOKEN" ]; then
            echo -e "${RED}Token no proporcionado${NC}"
            exit 1
        fi

        # Crear archivo de credenciales
        mkdir -p /etc/letsencrypt
        cat > "$CREDENTIALS_FILE" <<EOF
# Cloudflare API token
dns_cloudflare_api_token = $CF_TOKEN
EOF
        chmod 600 "$CREDENTIALS_FILE"
        echo -e "${GREEN}Credenciales guardadas en $CREDENTIALS_FILE${NC}"
    else
        echo -e "${GREEN}Usando credenciales existentes de $CREDENTIALS_FILE${NC}"
    fi
}

# Función para configurar credenciales de DigitalOcean
setup_digitalocean() {
    CREDENTIALS_FILE="/etc/letsencrypt/digitalocean.ini"

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        echo ""
        echo -e "${YELLOW}Configuración de DigitalOcean${NC}"
        echo "Necesitas un API Token de DigitalOcean con permisos de escritura."
        echo ""
        echo "Obtén tu token en: https://cloud.digitalocean.com/account/api/tokens"
        echo ""
        read -p "Ingresa tu DigitalOcean API Token: " DO_TOKEN

        if [ -z "$DO_TOKEN" ]; then
            echo -e "${RED}Token no proporcionado${NC}"
            exit 1
        fi

        # Crear archivo de credenciales
        mkdir -p /etc/letsencrypt
        cat > "$CREDENTIALS_FILE" <<EOF
# DigitalOcean API token
dns_digitalocean_token = $DO_TOKEN
EOF
        chmod 600 "$CREDENTIALS_FILE"
        echo -e "${GREEN}Credenciales guardadas en $CREDENTIALS_FILE${NC}"
    else
        echo -e "${GREEN}Usando credenciales existentes de $CREDENTIALS_FILE${NC}"
    fi
}

# Función para validación DNS manual
manual_dns_validation() {
    echo ""
    echo -e "${YELLOW}=========================================${NC}"
    echo -e "${YELLOW}VALIDACIÓN DNS MANUAL${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    echo ""
    echo "Para certificados wildcard, Let's Encrypt requiere que demuestres"
    echo "control sobre el dominio mediante un registro DNS TXT."
    echo ""
    echo -e "${BLUE}El proceso será:${NC}"
    echo "1. Certbot te mostrará un valor para el registro TXT"
    echo "2. Debes crear el registro en tu panel DNS:"
    echo "   - Nombre: _acme-challenge.$DOMAIN"
    echo "   - Tipo: TXT"
    echo "   - Valor: (el que te muestre certbot)"
    echo "3. Espera 1-5 minutos para propagación DNS"
    echo "4. Presiona Enter en certbot para continuar"
    echo ""
    echo -e "${YELLOW}IMPORTANTE: Certbot te pedirá crear DOS registros TXT${NC}"
    echo "(uno para el dominio base y otro para el wildcard)"
    echo ""
    read -p "Presiona Enter para continuar..."

    # Ejecutar certbot con validación manual
    certbot certonly \
        --manual \
        --preferred-challenges dns \
        -d "$DOMAIN" \
        -d "*.$DOMAIN" \
        --agree-tos \
        --email "$EMAIL"
}

# Ejecutar según el proveedor DNS
case $DNS_PROVIDER in
    cloudflare)
        install_dns_plugin cloudflare
        setup_cloudflare
        echo ""
        echo -e "${BLUE}Obteniendo certificado wildcard usando Cloudflare DNS...${NC}"
        certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
            --dns-cloudflare-propagation-seconds 30 \
            -d "$DOMAIN" \
            -d "*.$DOMAIN" \
            --agree-tos \
            --email "$EMAIL" \
            --non-interactive
        ;;

    digitalocean)
        install_dns_plugin digitalocean
        setup_digitalocean
        echo ""
        echo -e "${BLUE}Obteniendo certificado wildcard usando DigitalOcean DNS...${NC}"
        certbot certonly \
            --dns-digitalocean \
            --dns-digitalocean-credentials /etc/letsencrypt/digitalocean.ini \
            --dns-digitalocean-propagation-seconds 30 \
            -d "$DOMAIN" \
            -d "*.$DOMAIN" \
            --agree-tos \
            --email "$EMAIL" \
            --non-interactive
        ;;

    route53)
        install_dns_plugin route53
        echo ""
        echo -e "${YELLOW}Asegúrate de tener configuradas las credenciales AWS:${NC}"
        echo "  - AWS_ACCESS_KEY_ID"
        echo "  - AWS_SECRET_ACCESS_KEY"
        echo "  O el archivo ~/.aws/credentials"
        echo ""
        read -p "Presiona Enter para continuar..."

        certbot certonly \
            --dns-route53 \
            -d "$DOMAIN" \
            -d "*.$DOMAIN" \
            --agree-tos \
            --email "$EMAIL" \
            --non-interactive
        ;;

    google)
        install_dns_plugin google
        CREDENTIALS_FILE="/etc/letsencrypt/google.json"

        if [ ! -f "$CREDENTIALS_FILE" ]; then
            echo ""
            echo -e "${YELLOW}Configuración de Google Cloud DNS${NC}"
            echo "Necesitas un archivo JSON de service account con permisos DNS."
            echo ""
            read -p "Ruta al archivo JSON de credenciales: " GOOGLE_CREDS

            if [ ! -f "$GOOGLE_CREDS" ]; then
                echo -e "${RED}Archivo no encontrado: $GOOGLE_CREDS${NC}"
                exit 1
            fi

            cp "$GOOGLE_CREDS" "$CREDENTIALS_FILE"
            chmod 600 "$CREDENTIALS_FILE"
        fi

        certbot certonly \
            --dns-google \
            --dns-google-credentials "$CREDENTIALS_FILE" \
            -d "$DOMAIN" \
            -d "*.$DOMAIN" \
            --agree-tos \
            --email "$EMAIL" \
            --non-interactive
        ;;

    manual|*)
        manual_dns_validation
        ;;
esac

# Verificar si el certificado se obtuvo correctamente
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
if [ -d "$CERT_PATH" ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}Certificado Wildcard instalado${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "Archivos del certificado:"
    echo -e "  Certificado: ${BLUE}$CERT_PATH/fullchain.pem${NC}"
    echo -e "  Llave:       ${BLUE}$CERT_PATH/privkey.pem${NC}"
    echo ""

    # Mostrar información del certificado
    echo -e "${BLUE}Información del certificado:${NC}"
    certbot certificates -d "$DOMAIN"

    # Crear configuración de ejemplo para Nginx
    NGINX_WILDCARD_CONF="/etc/nginx/sites-available/wildcard-$DOMAIN.conf.example"
    cat > "$NGINX_WILDCARD_CONF" <<EOF
# Configuración de ejemplo para certificado wildcard
# Copia este archivo y modifícalo según tus necesidades

# Servidor para el dominio base
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

    ssl_certificate $CERT_PATH/fullchain.pem;
    ssl_certificate_key $CERT_PATH/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    root /var/www/$DOMAIN;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}

# Servidor para subdominios (wildcard)
# Ejemplo: api.$DOMAIN
server {
    listen 80;
    listen [::]:80;
    server_name api.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.$DOMAIN;

    ssl_certificate $CERT_PATH/fullchain.pem;
    ssl_certificate_key $CERT_PATH/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# Puedes agregar más subdominios usando el mismo certificado:
# app.$DOMAIN, blog.$DOMAIN, admin.$DOMAIN, etc.
# Todos usan los mismos archivos ssl_certificate
EOF

    echo ""
    echo -e "${BLUE}Configuración de ejemplo creada:${NC}"
    echo "  $NGINX_WILDCARD_CONF"
    echo ""
    echo -e "${YELLOW}Para usar el certificado wildcard en Nginx:${NC}"
    echo ""
    echo "  1. Copia y edita la configuración de ejemplo:"
    echo "     cp $NGINX_WILDCARD_CONF /etc/nginx/sites-available/mi-sitio.conf"
    echo ""
    echo "  2. Habilita el sitio:"
    echo "     ln -sf /etc/nginx/sites-available/mi-sitio.conf /etc/nginx/sites-enabled/"
    echo ""
    echo "  3. Prueba y recarga Nginx:"
    echo "     nginx -t && systemctl reload nginx"
    echo ""
    echo -e "${BLUE}Renovación automática:${NC}"
    if [ "$DNS_PROVIDER" = "manual" ]; then
        echo -e "  ${YELLOW}IMPORTANTE: Con validación manual, la renovación NO es automática.${NC}"
        echo "  Deberás ejecutar este script nuevamente antes de que expire."
        echo "  Considera usar un proveedor DNS soportado para renovación automática."
    else
        echo "  Los certificados se renovarán automáticamente."
        echo "  Verificar: systemctl status certbot.timer"
    fi
    echo ""
    echo -e "${GREEN}Prueba tu certificado:${NC}"
    echo "  https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
    echo ""
else
    echo ""
    echo -e "${RED}Error: No se pudo obtener el certificado${NC}"
    echo "Ver logs: /var/log/letsencrypt/letsencrypt.log"
    exit 1
fi

# Crear snippet de parámetros SSL si no existe
SSL_PARAMS="/etc/nginx/snippets/ssl-params.conf"
if [ ! -f "$SSL_PARAMS" ]; then
    echo -e "${BLUE}Creando configuración SSL optimizada...${NC}"
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

    # Generar parámetros Diffie-Hellman si no existen
    if [ ! -f "/etc/nginx/dhparam.pem" ]; then
        echo -e "${BLUE}Generando parámetros Diffie-Hellman (puede tomar unos minutos)...${NC}"
        openssl dhparam -out /etc/nginx/dhparam.pem 2048
    fi
fi

echo "========================================="
echo -e "${GREEN}Proceso completado${NC}"
echo "========================================="
