#!/bin/bash

# Script de verificación de sistema de monitoreo

echo "========================================="
echo "Verificación del Sistema de Monitoreo"
echo "========================================="
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
}

# 1. Verificar scripts de monitoreo básico
echo "1. Monitoreo básico"
echo "----------------------------"

if [ -f /usr/local/bin/vpc-monitor ]; then
    echo -e "$(check_status 0) Script de monitoreo instalado"
    if [ -f /etc/cron.d/vpc-monitoring ]; then
        echo -e "$(check_status 0) Cron job configurado"
    else
        echo -e "$(check_status 1) Cron job NO configurado"
    fi
else
    echo -e "$(check_status 1) Monitoreo básico no instalado"
    echo "  Ejecuta: ./setup-basic-monitoring.sh"
fi

if [ -d /var/log/monitoring ]; then
    echo -e "$(check_status 0) Directorio de logs existe"
    LOG_COUNT=$(ls -1 /var/log/monitoring/*.log 2>/dev/null | wc -l)
    echo "  Archivos de log: $LOG_COUNT"
else
    echo -e "$(check_status 1) Directorio de logs no existe"
fi

echo ""

# 2. Netdata
echo "2. Netdata"
echo "----------------------------"

if systemctl is-active --quiet netdata 2>/dev/null; then
    echo -e "$(check_status 0) Netdata activo"

    # Verificar puerto
    if netstat -tulpn 2>/dev/null | grep -q :19999 || ss -tulpn 2>/dev/null | grep -q :19999; then
        echo -e "$(check_status 0) Puerto 19999 en escucha"
    else
        echo -e "$(check_status 1) Puerto 19999 NO en escucha"
    fi

    # Verificar acceso
    if curl -s http://localhost:19999 > /dev/null 2>&1; then
        echo -e "$(check_status 0) Dashboard accesible"
    else
        echo -e "$(check_status 1) Dashboard NO accesible"
    fi

    # Uso de recursos
    MEM_USAGE=$(ps aux | grep netdata | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
    echo "  Uso de memoria: ${MEM_USAGE}MB"
else
    echo -e "$(check_status 1) Netdata no instalado"
    echo "  Ejecuta: ./install-netdata.sh"
fi

echo ""

# 3. Prometheus + Grafana (Docker)
echo "3. Prometheus + Grafana"
echo "----------------------------"

if command -v docker &> /dev/null && [ -f /opt/monitoring/docker-compose.yml ]; then
    cd /opt/monitoring

    # Prometheus
    if docker ps | grep -q prometheus; then
        echo -e "$(check_status 0) Prometheus corriendo"

        if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
            echo -e "$(check_status 0) Prometheus healthy"
        else
            echo -e "$(check_status 1) Prometheus NO healthy"
        fi
    else
        echo -e "$(check_status 1) Prometheus no corriendo"
    fi

    # Grafana
    if docker ps | grep -q grafana; then
        echo -e "$(check_status 0) Grafana corriendo"

        if curl -s http://localhost:3001/api/health > /dev/null 2>&1; then
            echo -e "$(check_status 0) Grafana healthy"
        else
            echo -e "$(check_status 1) Grafana NO healthy"
        fi
    else
        echo -e "$(check_status 1) Grafana no corriendo"
    fi

    # Node Exporter
    if docker ps | grep -q node-exporter; then
        echo -e "$(check_status 0) Node Exporter corriendo"
    else
        echo -e "$(check_status 1) Node Exporter no corriendo"
    fi

    # cAdvisor
    if docker ps | grep -q cadvisor; then
        echo -e "$(check_status 0) cAdvisor corriendo"
    else
        echo -e "$(check_status 1) cAdvisor no corriendo"
    fi

    # Ver recursos usados
    echo ""
    echo "  Uso de recursos (contenedores):"
    docker stats --no-stream --format "    {{.Name}}: {{.CPUPerc}} CPU, {{.MemUsage}}" \
        prometheus grafana node-exporter cadvisor 2>/dev/null || echo "    No disponible"

else
    echo -e "$(check_status 1) Stack Prometheus+Grafana no instalado"
    echo "  Ejecuta: ./install-prometheus-grafana.sh"
fi

echo ""

# 4. Configuración de email
echo "4. Alertas por Email"
echo "----------------------------"

if command -v mail &> /dev/null; then
    echo -e "$(check_status 0) Comando mail disponible"

    if systemctl is-active --quiet postfix 2>/dev/null; then
        echo -e "$(check_status 0) Postfix activo"
    else
        echo -e "$(check_status 1) Postfix no activo"
    fi
else
    echo -e "$(check_status 1) Comando mail no disponible"
    echo "  Instala: apt install mailutils"
fi

echo ""

# 5. Accesos configurados
echo "5. Accesos Web"
echo "----------------------------"

# Netdata
if systemctl is-active --quiet netdata 2>/dev/null; then
    if [ -f /etc/nginx/sites-enabled/netdata.conf ]; then
        NETDATA_DOMAIN=$(grep server_name /etc/nginx/sites-enabled/netdata.conf | head -1 | awk '{print $2}' | tr -d ';')
        echo "  Netdata: https://$NETDATA_DOMAIN"
    else
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "IP_NO_DISPONIBLE")
        echo "  Netdata: http://$SERVER_IP:19999"
    fi
fi

# Grafana
if docker ps 2>/dev/null | grep -q grafana; then
    if [ -f /etc/nginx/sites-enabled/grafana.conf ]; then
        GRAFANA_DOMAIN=$(grep server_name /etc/nginx/sites-enabled/grafana.conf | head -1 | awk '{print $2}' | tr -d ';')
        echo "  Grafana: https://$GRAFANA_DOMAIN"
    else
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "IP_NO_DISPONIBLE")
        echo "  Grafana: http://$SERVER_IP:3001"
    fi
fi

# Prometheus
if docker ps 2>/dev/null | grep -q prometheus; then
    if [ -f /etc/nginx/sites-enabled/prometheus.conf ]; then
        PROMETHEUS_DOMAIN=$(grep server_name /etc/nginx/sites-enabled/prometheus.conf | head -1 | awk '{print $2}' | tr -d ';')
        echo "  Prometheus: https://$PROMETHEUS_DOMAIN"
    else
        echo "  Prometheus: http://10.8.0.1:9090 (solo VPN)"
    fi
fi

echo ""

# 6. Logs recientes
echo "6. Logs de Monitoreo"
echo "----------------------------"

if [ -f /var/log/monitoring/monitor.log ]; then
    LAST_CHECK=$(stat -c %y /var/log/monitoring/monitor.log 2>/dev/null | cut -d'.' -f1)
    echo "  Última verificación: $LAST_CHECK"

    if [ -f /var/log/monitoring/alerts.log ]; then
        ALERT_COUNT=$(grep "$(date +%Y-%m-%d)" /var/log/monitoring/alerts.log 2>/dev/null | wc -l)
        echo "  Alertas hoy: $ALERT_COUNT"
    fi
else
    echo "  No hay logs de monitoreo básico"
fi

# Netdata logs
if systemctl is-active --quiet netdata 2>/dev/null; then
    ERROR_COUNT=$(journalctl -u netdata --since today 2>/dev/null | grep -i error | wc -l)
    echo "  Errores de Netdata hoy: $ERROR_COUNT"
fi

# Docker monitoring logs
if docker ps 2>/dev/null | grep -q prometheus; then
    echo "  Logs de contenedores disponibles: docker-compose logs"
fi

echo ""

# 7. Test de conectividad
echo "7. Test de Conectividad"
echo "----------------------------"

# Test Netdata
if systemctl is-active --quiet netdata 2>/dev/null; then
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:19999 | grep -q 200; then
        echo -e "$(check_status 0) Netdata responde (localhost:19999)"
    else
        echo -e "$(check_status 1) Netdata no responde"
    fi
fi

# Test Grafana
if docker ps 2>/dev/null | grep -q grafana; then
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/api/health | grep -q 200; then
        echo -e "$(check_status 0) Grafana responde (localhost:3001)"
    else
        echo -e "$(check_status 1) Grafana no responde"
    fi
fi

# Test Prometheus
if docker ps 2>/dev/null | grep -q prometheus; then
    if curl -s -o /dev/null http://localhost:9090/-/healthy; then
        echo -e "$(check_status 0) Prometheus responde (localhost:9090)"
    else
        echo -e "$(check_status 1) Prometheus no responde"
    fi
fi

echo ""

# 8. Resumen
echo "========================================="
echo "RESUMEN"
echo "========================================="
echo ""

TOOLS_INSTALLED=0

if [ -f /usr/local/bin/vpc-monitor ]; then
    echo -e "${GREEN}✓${NC} Monitoreo básico configurado"
    TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
fi

if systemctl is-active --quiet netdata 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Netdata activo"
    TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
fi

if docker ps 2>/dev/null | grep -q "prometheus\|grafana"; then
    echo -e "${GREEN}✓${NC} Prometheus + Grafana activo"
    TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
fi

if [ $TOOLS_INSTALLED -eq 0 ]; then
    echo -e "${YELLOW}⚠${NC} No hay herramientas de monitoreo instaladas"
    echo ""
    echo "Opciones disponibles:"
    echo "  ./setup-basic-monitoring.sh      - Monitoreo básico"
    echo "  ./install-netdata.sh             - Netdata (recomendado)"
    echo "  ./install-prometheus-grafana.sh  - Prometheus + Grafana"
else
    echo ""
    echo "Herramientas de monitoreo activas: $TOOLS_INSTALLED"
fi

echo ""
echo "========================================="
echo "Verificación completada"
echo "========================================="
