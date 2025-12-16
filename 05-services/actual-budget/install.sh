#!/bin/bash

# ============================================
# Instalador de Actual Budget
# App de finanzas personales self-hosted
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN="${1:-}"
EMAIL="${2:-}"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║       ACTUAL BUDGET - Instalador           ║"
echo "║    Finanzas personales self-hosted         ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar parámetros
if [ -z "$DOMAIN" ]; then
    echo -e "${YELLOW}Uso: $0 <subdominio.dominio.com> [email]${NC}"
    echo -e "${YELLOW}Ejemplo: $0 finanzas.midominio.com admin@midominio.com${NC}"
    echo ""
    read -p "Ingresa el dominio para Actual Budget: " DOMAIN
fi

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Debes especificar un dominio${NC}"
    exit 1
fi

# Extraer dominio base para certificados
BASE_DOMAIN=$(echo "$DOMAIN" | sed 's/^[^.]*\.//')

echo -e "${GREEN}Configuración:${NC}"
echo "  - Subdominio: $DOMAIN"
echo "  - Dominio base: $BASE_DOMAIN"
echo ""

# Verificar Docker
echo -e "${BLUE}[1/5] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker no está instalado${NC}"
    echo "Ejecuta primero el módulo 02-nginx-letsencrypt"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose no está instalado${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker instalado${NC}"

# Crear directorio de datos
echo -e "${BLUE}[2/5] Creando directorio de datos...${NC}"
mkdir -p "$SCRIPT_DIR/data"
chmod 755 "$SCRIPT_DIR/data"
echo -e "${GREEN}✓ Directorio creado${NC}"

# Iniciar contenedor
echo -e "${BLUE}[3/5] Iniciando Actual Budget...${NC}"
cd "$SCRIPT_DIR"

if docker compose version &> /dev/null; then
    docker compose up -d
else
    docker-compose up -d
fi

# Esperar a que inicie
echo -e "${YELLOW}Esperando que el servicio inicie...${NC}"
sleep 5

# Verificar que está corriendo
if docker ps | grep -q actual-budget; then
    echo -e "${GREEN}✓ Actual Budget corriendo en puerto 5006${NC}"
else
    echo -e "${RED}Error: El contenedor no inició correctamente${NC}"
    docker logs actual-budget
    exit 1
fi

# Configurar Nginx
echo -e "${BLUE}[4/5] Configurando Nginx...${NC}"

# Crear configuración con el dominio correcto
NGINX_CONF="/etc/nginx/sites-available/actual-budget"
sudo cp "$SCRIPT_DIR/nginx-actual.conf" "$NGINX_CONF"
sudo sed -i "s/finanzas.TU_DOMINIO.com/$DOMAIN/g" "$NGINX_CONF"
sudo sed -i "s/TU_DOMINIO.com/$BASE_DOMAIN/g" "$NGINX_CONF"

# Habilitar sitio
if [ ! -L /etc/nginx/sites-enabled/actual-budget ]; then
    sudo ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/
fi

# Verificar configuración
if sudo nginx -t; then
    sudo systemctl reload nginx
    echo -e "${GREEN}✓ Nginx configurado${NC}"
else
    echo -e "${RED}Error en configuración de Nginx${NC}"
    exit 1
fi

# Obtener certificado SSL si no existe
echo -e "${BLUE}[5/5] Verificando certificado SSL...${NC}"
if [ -f "/etc/letsencrypt/live/$BASE_DOMAIN/fullchain.pem" ]; then
    echo -e "${GREEN}✓ Certificado SSL existente${NC}"
else
    echo -e "${YELLOW}Obteniendo certificado SSL...${NC}"
    if [ -n "$EMAIL" ]; then
        sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"
    else
        sudo certbot --nginx -d "$DOMAIN"
    fi
fi

# Abrir puerto en firewall si es necesario
if command -v ufw &> /dev/null; then
    sudo ufw allow 'Nginx Full' 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗"
echo -e "║     ✓ INSTALACIÓN COMPLETADA              ║"
echo -e "╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Accede a Actual Budget:${NC}"
echo -e "  URL: ${GREEN}https://$DOMAIN${NC}"
echo ""
echo -e "${BLUE}Primer uso:${NC}"
echo "  1. Abre la URL en tu navegador"
echo "  2. Crea una contraseña para proteger el servidor"
echo "  3. Crea tu primer presupuesto"
echo ""
echo -e "${BLUE}Instalar como app en móvil:${NC}"
echo "  - iOS: Safari → Compartir → Añadir a pantalla de inicio"
echo "  - Android: Chrome → Menú → Instalar aplicación"
echo ""
echo -e "${BLUE}Datos guardados en:${NC}"
echo "  $SCRIPT_DIR/data/"
echo ""
echo -e "${YELLOW}Comandos útiles:${NC}"
echo "  Ver logs:     docker logs -f actual-budget"
echo "  Reiniciar:    docker restart actual-budget"
echo "  Detener:      docker stop actual-budget"
echo ""
