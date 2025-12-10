#!/bin/bash

# Script de monitoreo básico del sistema
# No requiere instalación adicional, usa herramientas del sistema

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "Reporte de Monitoreo del Sistema"
echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Hostname: $(hostname)"
echo "========================================="
echo ""

# Función para mostrar estado
status_icon() {
    local status=$1
    if [ "$status" = "ok" ]; then
        echo -e "${GREEN}✓${NC}"
    elif [ "$status" = "warning" ]; then
        echo -e "${YELLOW}⚠${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
}

# 1. UPTIME Y CARGA
echo "📊 UPTIME Y CARGA DEL SISTEMA"
echo "----------------------------"
uptime
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
LOAD_INT=$(echo $LOAD | cut -d'.' -f1)

if [ "$LOAD_INT" -lt 2 ]; then
    echo -e "Estado de carga: $(status_icon ok) Normal"
elif [ "$LOAD_INT" -lt 4 ]; then
    echo -e "Estado de carga: $(status_icon warning) Alta"
else
    echo -e "Estado de carga: $(status_icon error) Crítica"
fi
echo ""

# 2. CPU
echo "💻 USO DE CPU"
echo "----------------------------"
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
CPU_INT=$(echo $CPU_USAGE | cut -d'.' -f1)

echo "Uso actual: ${CPU_USAGE}%"

if [ "$CPU_INT" -lt 70 ]; then
    echo -e "Estado: $(status_icon ok) Normal"
elif [ "$CPU_INT" -lt 90 ]; then
    echo -e "Estado: $(status_icon warning) Alto"
else
    echo -e "Estado: $(status_icon error) Crítico"
fi

echo ""
echo "Top 5 procesos por CPU:"
ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "  %s\t%s%%\t%s\n", $11, $3, $2}'
echo ""

# 3. MEMORIA
echo "🧠 USO DE MEMORIA"
echo "----------------------------"
free -h | grep -v "Swap"
echo ""

MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_USED=$(free | grep Mem | awk '{print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

echo "Uso de memoria: ${MEM_PERCENT}%"

if [ "$MEM_PERCENT" -lt 80 ]; then
    echo -e "Estado: $(status_icon ok) Normal"
elif [ "$MEM_PERCENT" -lt 95 ]; then
    echo -e "Estado: $(status_icon warning) Alto"
else
    echo -e "Estado: $(status_icon error) Crítico"
fi

echo ""
echo "Top 5 procesos por memoria:"
ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "  %s\t%s%%\t%s\n", $11, $4, $2}'
echo ""

# 4. DISCO
echo "💾 USO DE DISCO"
echo "----------------------------"
df -h | grep -vE "tmpfs|devtmpfs|loop"
echo ""

DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')

if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "Estado del disco: $(status_icon ok) Normal"
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "Estado del disco: $(status_icon warning) Alto"
else
    echo -e "Estado del disco: $(status_icon error) Crítico"
fi
echo ""

# 5. SERVICIOS CRÍTICOS
echo "🔧 SERVICIOS CRÍTICOS"
echo "----------------------------"

check_service() {
    local service=$1
    local name=$2

    if systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "$(status_icon ok) $name: Activo"
        return 0
    else
        echo -e "$(status_icon error) $name: INACTIVO"
        return 1
    fi
}

check_service "ssh" "SSH"
check_service "nginx" "Nginx"
check_service "fail2ban" "Fail2ban"
check_service "ufw" "Firewall (UFW)"
check_service "wg-quick@wg0" "WireGuard VPN"
check_service "docker" "Docker"
check_service "netdata" "Netdata" 2>/dev/null || echo -e "${BLUE}ℹ${NC} Netdata: No instalado"

echo ""

# 6. INTENTOS DE INTRUSIÓN (FAIL2BAN)
echo "🛡️  SEGURIDAD - FAIL2BAN"
echo "----------------------------"
if systemctl is-active --quiet fail2ban; then
    echo "IPs baneadas actualmente:"
    BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
    if [ "$BANNED" = "0" ] || [ -z "$BANNED" ]; then
        echo -e "  $(status_icon ok) Ninguna IP baneada"
    else
        echo -e "  $(status_icon warning) $BANNED IPs baneadas"
        fail2ban-client status sshd 2>/dev/null | grep "Banned IP list" | cut -d: -f2
    fi

    echo ""
    echo "Intentos de intrusión (últimas 24h):"
    FAILED_SSH=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)
    echo "  Intentos SSH fallidos: $FAILED_SSH"
else
    echo -e "$(status_icon warning) Fail2ban no está activo"
fi
echo ""

# 7. WIREGUARD VPN
echo "🔒 WIREGUARD VPN"
echo "----------------------------"
if systemctl is-active --quiet wg-quick@wg0; then
    CLIENTS_CONNECTED=$(wg show wg0 peers 2>/dev/null | wc -l)
    echo "Clientes conectados: $CLIENTS_CONNECTED"

    if [ "$CLIENTS_CONNECTED" -gt 0 ]; then
        echo ""
        echo "Tráfico por cliente:"
        wg show wg0 transfer 2>/dev/null | while read line; do
            echo "  $line"
        done
    fi
else
    echo -e "$(status_icon warning) WireGuard no está activo"
fi
echo ""

# 8. NGINX
echo "🌐 NGINX"
echo "----------------------------"
if systemctl is-active --quiet nginx; then
    echo -e "$(status_icon ok) Nginx activo"

    if [ -f /var/log/nginx/access.log ]; then
        echo ""
        echo "Estadísticas últimas 24h:"

        # Total de peticiones
        REQUESTS=$(grep "$(date +%d/%b/%Y)" /var/log/nginx/access.log 2>/dev/null | wc -l)
        echo "  Total peticiones: $REQUESTS"

        # Códigos de respuesta
        echo ""
        echo "  Códigos de respuesta:"
        grep "$(date +%d/%b/%Y)" /var/log/nginx/access.log 2>/dev/null | \
            awk '{print $9}' | sort | uniq -c | sort -rn | head -5 | \
            while read count code; do
                echo "    $code: $count veces"
            done

        # Top IPs
        echo ""
        echo "  Top 5 IPs:"
        grep "$(date +%d/%b/%Y)" /var/log/nginx/access.log 2>/dev/null | \
            awk '{print $1}' | sort | uniq -c | sort -rn | head -5 | \
            while read count ip; do
                echo "    $ip: $count peticiones"
            done
    fi
else
    echo -e "$(status_icon error) Nginx INACTIVO"
fi
echo ""

# 9. CERTIFICADOS SSL
echo "🔐 CERTIFICADOS SSL"
echo "----------------------------"
if command -v certbot &> /dev/null; then
    CERTS=$(certbot certificates 2>/dev/null | grep "Certificate Name:" | wc -l)
    echo "Certificados instalados: $CERTS"

    if [ "$CERTS" -gt 0 ]; then
        echo ""
        certbot certificates 2>/dev/null | grep -A 2 "Certificate Name:" | while read line; do
            if [[ $line == *"Certificate Name"* ]]; then
                echo "  $line"
            elif [[ $line == *"Expiry Date"* ]]; then
                EXPIRY=$(echo $line | grep -oP '\d{4}-\d{2}-\d{2}')
                DAYS_LEFT=$(( ($(date -d "$EXPIRY" +%s) - $(date +%s)) / 86400 ))

                if [ "$DAYS_LEFT" -gt 30 ]; then
                    echo -e "    Expira en: $DAYS_LEFT días $(status_icon ok)"
                elif [ "$DAYS_LEFT" -gt 7 ]; then
                    echo -e "    Expira en: $DAYS_LEFT días $(status_icon warning)"
                else
                    echo -e "    Expira en: $DAYS_LEFT días $(status_icon error) ¡URGENTE!"
                fi
            fi
        done
    fi
else
    echo -e "${BLUE}ℹ${NC} Certbot no instalado"
fi
echo ""

# 10. DOCKER
echo "🐳 DOCKER"
echo "----------------------------"
if systemctl is-active --quiet docker; then
    CONTAINERS_RUNNING=$(docker ps -q 2>/dev/null | wc -l)
    CONTAINERS_TOTAL=$(docker ps -a -q 2>/dev/null | wc -l)

    echo "Contenedores corriendo: $CONTAINERS_RUNNING / $CONTAINERS_TOTAL"

    if [ "$CONTAINERS_RUNNING" -gt 0 ]; then
        echo ""
        echo "Contenedores activos:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tail -n +2 | \
            while IFS= read -r line; do
                echo "  $line"
            done

        echo ""
        echo "Uso de recursos por contenedor:"
        docker stats --no-stream --format "  {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null
    fi
else
    echo -e "${BLUE}ℹ${NC} Docker no instalado o inactivo"
fi
echo ""

# 11. RED
echo "🌐 RED Y CONECTIVIDAD"
echo "----------------------------"
echo "Interfaces de red:"
ip -br addr show | grep -v "lo" | while read line; do
    echo "  $line"
done

echo ""
echo "Puertos en escucha:"
ss -tulpn | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -n | uniq | head -10 | \
    while read port; do
        SERVICE=$(ss -tulpn | grep ":$port" | awk '{print $7}' | cut -d'"' -f2 | head -1)
        echo "  Puerto $port: $SERVICE"
    done

echo ""
echo "Test de conectividad:"
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "  $(status_icon ok) Internet: Conectado"
else
    echo -e "  $(status_icon error) Internet: Sin conexión"
fi

if ping -c 1 google.com &> /dev/null; then
    echo -e "  $(status_icon ok) DNS: Funcionando"
else
    echo -e "  $(status_icon error) DNS: Error"
fi
echo ""

# 12. ERRORES RECIENTES EN LOGS
echo "📝 ERRORES RECIENTES"
echo "----------------------------"

echo "Nginx errors (últimas 5):"
if [ -f /var/log/nginx/error.log ]; then
    tail -5 /var/log/nginx/error.log 2>/dev/null | sed 's/^/  /'
else
    echo "  Sin errores o log no disponible"
fi

echo ""
echo "Errores del sistema (últimas 5):"
journalctl -p err -n 5 --no-pager 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  No disponible"

echo ""

# 13. RESUMEN Y RECOMENDACIONES
echo "========================================="
echo "📋 RESUMEN"
echo "========================================="
echo ""

# Generar alerta si hay problemas
ALERTS=0

if [ "$CPU_INT" -gt 90 ]; then
    echo -e "${RED}⚠ ALERTA:${NC} CPU crítica (${CPU_USAGE}%)"
    ALERTS=$((ALERTS + 1))
fi

if [ "$MEM_PERCENT" -gt 95 ]; then
    echo -e "${RED}⚠ ALERTA:${NC} Memoria crítica (${MEM_PERCENT}%)"
    ALERTS=$((ALERTS + 1))
fi

if [ "$DISK_USAGE" -gt 90 ]; then
    echo -e "${RED}⚠ ALERTA:${NC} Disco crítico (${DISK_USAGE}%)"
    ALERTS=$((ALERTS + 1))
fi

# Verificar servicios críticos
for service in ssh nginx fail2ban ufw; do
    if ! systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "${RED}⚠ ALERTA:${NC} Servicio $service inactivo"
        ALERTS=$((ALERTS + 1))
    fi
done

if [ "$ALERTS" -eq 0 ]; then
    echo -e "${GREEN}✓ Todo funcionando correctamente${NC}"
else
    echo ""
    echo -e "${RED}Se encontraron $ALERTS problemas que requieren atención${NC}"
fi

echo ""
echo "========================================="
echo "Reporte generado: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
