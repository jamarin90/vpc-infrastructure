#!/bin/bash

# Script de verificación completa del sistema
# Ejecutar en el servidor

echo "========================================="
echo "Verificación completa del sistema VPC"
echo "========================================="
echo ""
echo "Servidor: $(hostname)"
echo "Fecha: $(date)"
echo ""

# Contadores
PASS=0
FAIL=0
WARN=0

# Función para mostrar resultado
check() {
    local result=$1
    local name=$2

    if [ $result -eq 0 ]; then
        echo "✅ $name"
        PASS=$((PASS + 1))
    elif [ $result -eq 2 ]; then
        echo "⚠️  $name"
        WARN=$((WARN + 1))
    else
        echo "❌ $name"
        FAIL=$((FAIL + 1))
    fi
}

# 1. SSH y Seguridad
echo "🔐 SEGURIDAD"
echo "----------------------------"

systemctl is-active --quiet ssh
check $? "SSH corriendo"

systemctl is-active --quiet fail2ban
check $? "fail2ban corriendo"

systemctl is-active --quiet ufw
check $? "Firewall (ufw) activo"

if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    check 0 "SSH password auth deshabilitado"
else
    check 1 "SSH password auth HABILITADO (peligroso)"
fi

echo ""

# 2. Web Server
echo "🌐 NGINX"
echo "----------------------------"

systemctl is-active --quiet nginx
check $? "Nginx corriendo"

nginx -t > /dev/null 2>&1
check $? "Configuración Nginx válida"

SITES=$(ls /etc/nginx/sites-enabled/ 2>/dev/null | grep -v default | wc -l)
echo "   Sitios configurados: $SITES"

echo ""

# 3. SSL
echo "🔒 CERTIFICADOS SSL"
echo "----------------------------"

if command -v certbot &> /dev/null; then
    CERTS=$(certbot certificates 2>/dev/null | grep "Certificate Name:" | wc -l)
    echo "   Certificados instalados: $CERTS"

    if [ $CERTS -gt 0 ]; then
        check 0 "Let's Encrypt configurado"

        # Verificar expiración
        EXPIRING=$(certbot certificates 2>/dev/null | grep "VALID:" | grep -E "0 days|[1-7] days" | wc -l)
        if [ $EXPIRING -gt 0 ]; then
            check 2 "Certificados por expirar pronto"
        else
            check 0 "Certificados válidos"
        fi
    else
        check 2 "Sin certificados SSL"
    fi

    systemctl is-active --quiet certbot.timer
    check $? "Auto-renovación configurada"
else
    check 2 "Certbot no instalado"
fi

echo ""

# 4. VPN
echo "🔒 WIREGUARD VPN"
echo "----------------------------"

if systemctl is-active --quiet wg-quick@wg0; then
    check 0 "WireGuard corriendo"

    CLIENTS=$(wg show wg0 peers 2>/dev/null | wc -l)
    CONNECTED=$(wg show wg0 endpoints 2>/dev/null | wc -l)
    echo "   Clientes conectados: $CONNECTED / $CLIENTS"

    if [ $CLIENTS -gt 0 ]; then
        check 0 "Clientes VPN configurados"
    else
        check 2 "Sin clientes VPN"
    fi
else
    check 2 "WireGuard no instalado/activo"
fi

echo ""

# 5. Monitoreo
echo "📊 MONITOREO"
echo "----------------------------"

# Netdata
if systemctl is-active --quiet netdata; then
    check 0 "Netdata corriendo"

    if curl -s http://localhost:19999 > /dev/null 2>&1; then
        check 0 "Netdata responde"
    else
        check 1 "Netdata no responde"
    fi
else
    check 2 "Netdata no instalado"
fi

# Docker monitoring
if command -v docker &> /dev/null; then
    CONTAINERS=$(docker ps -q 2>/dev/null | wc -l)

    if docker ps 2>/dev/null | grep -q prometheus; then
        check 0 "Prometheus corriendo"
    else
        check 2 "Prometheus no instalado"
    fi

    if docker ps 2>/dev/null | grep -q grafana; then
        check 0 "Grafana corriendo"
    else
        check 2 "Grafana no instalado"
    fi

    echo "   Contenedores Docker: $CONTAINERS"
else
    check 2 "Docker no instalado"
fi

# Monitoreo básico
if [ -f /usr/local/bin/vpc-monitor ]; then
    check 0 "Monitoreo básico configurado"

    if [ -f /etc/cron.d/vpc-monitoring ]; then
        check 0 "Cron de monitoreo activo"
    else
        check 2 "Cron de monitoreo no configurado"
    fi
else
    check 2 "Monitoreo básico no configurado"
fi

echo ""

# 6. Recursos del sistema
echo "💻 RECURSOS DEL SISTEMA"
echo "----------------------------"

# CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)
echo "   CPU: ${CPU_USAGE}%"
if [ $CPU_USAGE -lt 80 ]; then
    check 0 "Uso de CPU normal"
elif [ $CPU_USAGE -lt 95 ]; then
    check 2 "Uso de CPU alto"
else
    check 1 "Uso de CPU crítico"
fi

# Memoria
MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_USED=$(free | grep Mem | awk '{print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
echo "   Memoria: ${MEM_PERCENT}%"
if [ $MEM_PERCENT -lt 85 ]; then
    check 0 "Uso de memoria normal"
elif [ $MEM_PERCENT -lt 95 ]; then
    check 2 "Uso de memoria alto"
else
    check 1 "Uso de memoria crítico"
fi

# Disco
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
echo "   Disco: ${DISK_USAGE}%"
if [ $DISK_USAGE -lt 85 ]; then
    check 0 "Uso de disco normal"
elif [ $DISK_USAGE -lt 95 ]; then
    check 2 "Uso de disco alto"
else
    check 1 "Uso de disco crítico"
fi

echo ""

# 7. Conectividad
echo "🌐 CONECTIVIDAD"
echo "----------------------------"

if ping -c 1 8.8.8.8 &> /dev/null; then
    check 0 "Internet funciona"
else
    check 1 "Sin conexión a Internet"
fi

if ping -c 1 google.com &> /dev/null; then
    check 0 "DNS funciona"
else
    check 1 "DNS no funciona"
fi

echo ""

# 8. Seguridad - Intentos de intrusión
echo "🛡️  SEGURIDAD - INTENTOS DE INTRUSIÓN"
echo "----------------------------"

if systemctl is-active --quiet fail2ban; then
    BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
    echo "   IPs baneadas actualmente: ${BANNED:-0}"

    FAILED_TODAY=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)
    echo "   Intentos SSH fallidos hoy: $FAILED_TODAY"

    if [ $FAILED_TODAY -lt 10 ]; then
        check 0 "Nivel de ataques bajo"
    elif [ $FAILED_TODAY -lt 50 ]; then
        check 2 "Nivel de ataques medio"
    else
        check 2 "Nivel de ataques alto"
    fi
fi

echo ""

# Resumen final
echo "========================================="
echo "RESUMEN"
echo "========================================="
echo ""
echo "✅ Pasaron: $PASS"
echo "⚠️  Advertencias: $WARN"
echo "❌ Fallaron: $FAIL"
echo ""

TOTAL=$((PASS + WARN + FAIL))
if [ $TOTAL -gt 0 ]; then
    SUCCESS_RATE=$(( PASS * 100 / TOTAL ))
    echo "Tasa de éxito: ${SUCCESS_RATE}%"
fi

echo ""

if [ $FAIL -eq 0 ]; then
    echo "🎉 Sistema funcionando correctamente"
    exit 0
elif [ $FAIL -lt 3 ]; then
    echo "⚠️  Sistema funcionando con advertencias menores"
    exit 0
else
    echo "❌ Sistema requiere atención"
    exit 1
fi
