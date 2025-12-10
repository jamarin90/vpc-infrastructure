#!/bin/bash

# Script de instalación de Prometheus + Grafana
# Stack profesional de monitoreo con Docker Compose

set -e

echo "========================================="
echo "Instalación de Prometheus + Grafana"
echo "========================================="
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

# Verificar que Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado"
    echo "Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Instalando Docker Compose..."
    apt-get update
    apt-get install -y docker-compose
fi

echo "✓ Docker y Docker Compose disponibles"
echo ""

# Preguntar configuración
read -p "¿Quieres acceder a Grafana por dominio con SSL? (s/N): " -n 1 -r
echo ""

USE_DOMAIN=false
if [[ $REPLY =~ ^[Ss]$ ]]; then
    USE_DOMAIN=true
    read -p "Dominio para Grafana (ej: grafana.tu-dominio.com): " GRAFANA_DOMAIN
    read -p "Dominio para Prometheus [opcional] (ej: prometheus.tu-dominio.com): " PROMETHEUS_DOMAIN
    read -p "Email para Let's Encrypt: " EMAIL
fi

# Generar contraseña aleatoria para Grafana
GRAFANA_PASSWORD=$(openssl rand -base64 12)
echo ""
echo "🔐 Contraseña de Grafana generada: $GRAFANA_PASSWORD"
echo "(guarda esta contraseña, la necesitarás para acceder)"
echo ""

read -p "¿Continuar con la instalación? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "❌ Instalación cancelada"
    exit 1
fi

# Crear directorio para monitoreo
MONITORING_DIR="/opt/monitoring"
mkdir -p $MONITORING_DIR
cd $MONITORING_DIR

# Copiar archivos de configuración
echo "📝 Copiando archivos de configuración..."
cp ~/vpc/04-monitoring/docker-compose-monitoring.yml ./docker-compose.yml
cp ~/vpc/04-monitoring/prometheus.yml ./prometheus.yml

# Crear archivo .env
cat > .env <<EOF
GRAFANA_PASSWORD=$GRAFANA_PASSWORD
DOMAIN=${GRAFANA_DOMAIN:-localhost}
EOF

# Crear directorio para dashboards de Grafana
mkdir -p grafana-dashboards

# Crear configuración básica de alertmanager
cat > alertmanager.yml <<EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'

receivers:
  - name: 'default'
    # Configurar aquí email, Slack, etc.
    # Ver: https://prometheus.io/docs/alerting/latest/configuration/

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster']
EOF

# Iniciar stack
echo ""
echo "🚀 Iniciando stack de monitoreo..."
docker-compose up -d

# Esperar a que arranquen los servicios
echo "Esperando a que los servicios arranquen..."
sleep 15

# Verificar que están corriendo
if docker ps | grep -q prometheus && docker ps | grep -q grafana; then
    echo "✅ Servicios iniciados correctamente"
else
    echo "❌ Error al iniciar servicios"
    docker-compose logs
    exit 1
fi

# Configurar Nginx reverse proxy si se usa dominio
if [ "$USE_DOMAIN" = true ]; then
    echo ""
    echo "🌐 Configurando Nginx reverse proxy..."

    # Grafana
    cat > /etc/nginx/sites-available/grafana.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $GRAFANA_DOMAIN;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/grafana.conf /etc/nginx/sites-enabled/

    # Prometheus (si se especificó dominio)
    if [ -n "$PROMETHEUS_DOMAIN" ]; then
        cat > /etc/nginx/sites-available/prometheus.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $PROMETHEUS_DOMAIN;

    # Autenticación básica
    auth_basic "Prometheus";
    auth_basic_user_file /etc/nginx/.htpasswd-prometheus;

    location / {
        proxy_pass http://localhost:9090;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

        ln -sf /etc/nginx/sites-available/prometheus.conf /etc/nginx/sites-enabled/

        # Crear usuario para Prometheus
        apt-get install -y apache2-utils
        echo "Crear usuario para Prometheus:"
        htpasswd -c /etc/nginx/.htpasswd-prometheus admin
    fi

    # Probar y recargar Nginx
    nginx -t && systemctl reload nginx

    # Obtener certificados SSL
    echo ""
    echo "🔒 Obteniendo certificados SSL..."

    certbot --nginx -d $GRAFANA_DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

    if [ -n "$PROMETHEUS_DOMAIN" ]; then
        certbot --nginx -d $PROMETHEUS_DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect
    fi
fi

# Guardar información de acceso
cat > $MONITORING_DIR/ACCESS_INFO.txt <<EOF
========================================
Información de Acceso - Monitoring Stack
========================================

Grafana:
EOF

if [ "$USE_DOMAIN" = true ]; then
    cat >> $MONITORING_DIR/ACCESS_INFO.txt <<EOF
  URL: https://$GRAFANA_DOMAIN
EOF
else
    cat >> $MONITORING_DIR/ACCESS_INFO.txt <<EOF
  URL: http://$(curl -s ifconfig.me):3001
  URL (VPN): http://10.8.0.1:3001
EOF
fi

cat >> $MONITORING_DIR/ACCESS_INFO.txt <<EOF
  Usuario: admin
  Contraseña: $GRAFANA_PASSWORD

Prometheus:
EOF

if [ -n "$PROMETHEUS_DOMAIN" ]; then
    cat >> $MONITORING_DIR/ACCESS_INFO.txt <<EOF
  URL: https://$PROMETHEUS_DOMAIN
  Usuario: admin
  Contraseña: (la que configuraste)
EOF
else
    cat >> $MONITORING_DIR/ACCESS_INFO.txt <<EOF
  URL: http://$(curl -s ifconfig.me):9090
  URL (VPN): http://10.8.0.1:9090
EOF
fi

cat >> $MONITORING_DIR/ACCESS_INFO.txt <<EOF

cAdvisor (Docker metrics):
  URL: http://10.8.0.1:8080

Node Exporter (System metrics):
  URL: http://10.8.0.1:9100/metrics

Gestión:
  Ubicación: $MONITORING_DIR
  Ver logs: docker-compose logs -f
  Reiniciar: docker-compose restart
  Detener: docker-compose down
  Iniciar: docker-compose up -d

Configuración:
  Prometheus: $MONITORING_DIR/prometheus.yml
  AlertManager: $MONITORING_DIR/alertmanager.yml
  Docker Compose: $MONITORING_DIR/docker-compose.yml

Dashboards Grafana recomendados:
  - Node Exporter Full (ID: 1860)
  - Docker and System Monitoring (ID: 893)
  - Prometheus Stats (ID: 3662)

Para importar dashboards:
  1. Ve a Grafana > Dashboards > Import
  2. Ingresa el ID del dashboard
  3. Selecciona Prometheus como datasource
  4. Import

========================================
EOF

echo ""
echo "========================================="
echo "✅ Instalación completada"
echo "========================================="
echo ""

cat $MONITORING_DIR/ACCESS_INFO.txt

echo ""
echo "📊 Dashboards recomendados para Grafana:"
echo ""
echo "1. Node Exporter Full (1860)"
echo "   - Dashboard completo del sistema"
echo "   https://grafana.com/grafana/dashboards/1860"
echo ""
echo "2. Docker Container & Host Metrics (10619)"
echo "   - Monitoreo de Docker"
echo "   https://grafana.com/grafana/dashboards/10619"
echo ""
echo "3. Nginx Metrics (12708)"
echo "   - Si instalas nginx-exporter"
echo "   https://grafana.com/grafana/dashboards/12708"
echo ""
echo "Para importar: Grafana > + > Import Dashboard > Pegar ID"
echo ""
echo "💡 Primera configuración en Grafana:"
echo "1. Accede a Grafana con las credenciales de arriba"
echo "2. Ve a Configuration > Data Sources"
echo "3. Prometheus debería estar configurado automáticamente"
echo "4. Importa los dashboards recomendados"
echo "5. Explora las métricas!"
echo ""
echo "📁 Información guardada en: $MONITORING_DIR/ACCESS_INFO.txt"
echo ""
echo "========================================="
