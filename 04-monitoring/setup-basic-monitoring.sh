#!/bin/bash

# Script para configurar monitoreo básico automático
# Configura cron jobs para ejecutar reportes y enviar alertas

set -e

echo "========================================="
echo "Configuración de Monitoreo Automático"
echo "========================================="
echo ""

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script debe ejecutarse como root"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Este script configurará:"
echo "  - Monitoreo cada hora"
echo "  - Reporte diario por email"
echo "  - Alertas inmediatas si hay problemas críticos"
echo ""

# Preguntar por email
read -p "¿Quieres recibir reportes por email? (s/N): " -n 1 -r
echo ""

SEND_EMAIL=false
if [[ $REPLY =~ ^[Ss]$ ]]; then
    SEND_EMAIL=true
    read -p "Email destino: " EMAIL_TO
    echo ""
fi

# Crear directorio para logs
MONITOR_DIR="/var/log/monitoring"
mkdir -p $MONITOR_DIR

# Crear script de monitoreo con email
cat > /usr/local/bin/vpc-monitor <<'MONITOR_SCRIPT'
#!/bin/bash

# Script ejecutado por cron para monitoreo automático

MONITOR_LOG="/var/log/monitoring/monitor.log"
ALERT_LOG="/var/log/monitoring/alerts.log"
SEND_EMAIL=__SEND_EMAIL__
EMAIL_TO="__EMAIL_TO__"

# Función para enviar email
send_email() {
    local subject="$1"
    local body="$2"

    if [ "$SEND_EMAIL" = "true" ]; then
        echo "$body" | mail -s "$subject" "$EMAIL_TO"
    fi
}

# Ejecutar monitoreo básico
REPORT=$(__SCRIPT_DIR__/basic-monitor.sh)

# Guardar en log
echo "=== $(date) ===" >> $MONITOR_LOG
echo "$REPORT" >> $MONITOR_LOG

# Verificar alertas críticas
ALERTS=$(echo "$REPORT" | grep -c "⚠ ALERTA:" || echo "0")

if [ "$ALERTS" -gt 0 ]; then
    # Hay alertas, enviar email
    SUBJECT="[ALERTA] VPC $(hostname) - $ALERTS problemas detectados"

    echo "$(date): $ALERTS alertas detectadas" >> $ALERT_LOG

    if [ "$SEND_EMAIL" = "true" ]; then
        send_email "$SUBJECT" "$REPORT"
        echo "Email de alerta enviado a $EMAIL_TO" >> $ALERT_LOG
    fi
fi

# Limitar tamaño de logs (mantener últimos 1000 líneas)
tail -1000 $MONITOR_LOG > ${MONITOR_LOG}.tmp && mv ${MONITOR_LOG}.tmp $MONITOR_LOG
tail -1000 $ALERT_LOG > ${ALERT_LOG}.tmp && mv ${ALERT_LOG}.tmp $ALERT_LOG
MONITOR_SCRIPT

# Reemplazar placeholders
sed -i "s|__SCRIPT_DIR__|$SCRIPT_DIR|g" /usr/local/bin/vpc-monitor
sed -i "s|__SEND_EMAIL__|$SEND_EMAIL|g" /usr/local/bin/vpc-monitor
sed -i "s|__EMAIL_TO__|$EMAIL_TO|g" /usr/local/bin/vpc-monitor

chmod +x /usr/local/bin/vpc-monitor

# Crear script de reporte diario
cat > /usr/local/bin/vpc-daily-report <<DAILY_SCRIPT
#!/bin/bash

# Reporte diario del sistema

REPORT_FILE="/var/log/monitoring/daily-report-\$(date +%Y%m%d).log"
SEND_EMAIL=$SEND_EMAIL
EMAIL_TO="$EMAIL_TO"

# Generar reporte
{
    echo "========================================="
    echo "Reporte Diario - \$(date '+%Y-%m-%d')"
    echo "Servidor: \$(hostname)"
    echo "========================================="
    echo ""

    # Resumen de uptime
    echo "📊 RESUMEN DEL SISTEMA"
    echo "----------------------------"
    uptime
    echo ""

    # Uso promedio de recursos
    echo "💻 RECURSOS"
    echo "----------------------------"
    echo "CPU promedio (últimas 24h):"
    sar -u 1 1 2>/dev/null | tail -1 || echo "  (sar no disponible)"
    echo ""
    echo "Memoria:"
    free -h
    echo ""
    echo "Disco:"
    df -h / | tail -1
    echo ""

    # Servicios
    echo "🔧 SERVICIOS"
    echo "----------------------------"
    for service in ssh nginx fail2ban ufw wg-quick@wg0 docker; do
        if systemctl is-active --quiet \$service 2>/dev/null; then
            echo "  ✓ \$service"
        else
            echo "  ✗ \$service (INACTIVO)"
        fi
    done
    echo ""

    # Seguridad - fail2ban
    echo "🛡️  SEGURIDAD"
    echo "----------------------------"
    if systemctl is-active --quiet fail2ban; then
        echo "IPs baneadas hoy:"
        grep "\$(date +%Y-%m-%d)" /var/log/fail2ban.log 2>/dev/null | grep "Ban" | wc -l
        echo ""
        echo "Intentos SSH fallidos:"
        grep "Failed password" /var/log/auth.log 2>/dev/null | grep "\$(date +%b\ %d)" | wc -l
    fi
    echo ""

    # Nginx stats
    echo "🌐 NGINX"
    echo "----------------------------"
    if [ -f /var/log/nginx/access.log ]; then
        REQUESTS=\$(grep "\$(date +%d/%b/%Y)" /var/log/nginx/access.log 2>/dev/null | wc -l)
        echo "Peticiones hoy: \$REQUESTS"
        echo ""
        echo "Top 5 IPs:"
        grep "\$(date +%d/%b/%Y)" /var/log/nginx/access.log 2>/dev/null | \\
            awk '{print \$1}' | sort | uniq -c | sort -rn | head -5
    fi
    echo ""

    # VPN
    echo "🔒 VPN"
    echo "----------------------------"
    if systemctl is-active --quiet wg-quick@wg0; then
        wg show wg0 2>/dev/null | head -10
    else
        echo "  WireGuard no activo"
    fi
    echo ""

    # Docker
    echo "🐳 DOCKER"
    echo "----------------------------"
    if systemctl is-active --quiet docker; then
        echo "Contenedores:"
        docker ps --format "  {{.Names}}: {{.Status}}"
    fi
    echo ""

    echo "========================================="
    echo "Fin del reporte"
    echo "========================================="

} > \$REPORT_FILE

# Enviar por email si está configurado
if [ "\$SEND_EMAIL" = "true" ]; then
    mail -s "Reporte Diario - VPC \$(hostname)" "\$EMAIL_TO" < \$REPORT_FILE
fi

# Mantener solo los últimos 30 días de reportes
find /var/log/monitoring -name "daily-report-*.log" -mtime +30 -delete
DAILY_SCRIPT

chmod +x /usr/local/bin/vpc-daily-report

# Configurar cron jobs
echo ""
echo "⚙️  Configurando tareas automáticas..."

# Crear archivo de cron
cat > /etc/cron.d/vpc-monitoring <<CRON
# Monitoreo automático de VPC

# Monitoreo cada hora (buscar problemas)
0 * * * * root /usr/local/bin/vpc-monitor

# Reporte diario a las 8:00 AM
0 8 * * * root /usr/local/bin/vpc-daily-report

# Limpiar logs viejos (cada semana)
0 3 * * 0 root find /var/log/monitoring -type f -mtime +30 -delete
CRON

chmod 644 /etc/cron.d/vpc-monitoring

# Instalar mail si no está y se necesita
if [ "$SEND_EMAIL" = "true" ]; then
    if ! command -v mail &> /dev/null; then
        echo ""
        echo "📧 Instalando utilidad de mail..."
        apt-get update
        apt-get install -y mailutils

        echo ""
        echo "⚠️  IMPORTANTE: Configura el servidor SMTP"
        echo ""
        echo "Edita /etc/postfix/main.cf y configura:"
        echo "  relayhost = [smtp.gmail.com]:587"
        echo "  smtp_use_tls = yes"
        echo "  smtp_sasl_auth_enable = yes"
        echo "  smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
        echo ""
        echo "Y crea /etc/postfix/sasl_passwd:"
        echo "  [smtp.gmail.com]:587 tu-email@gmail.com:tu-password"
        echo ""
        echo "Luego ejecuta:"
        echo "  postmap /etc/postfix/sasl_passwd"
        echo "  chmod 600 /etc/postfix/sasl_passwd*"
        echo "  systemctl restart postfix"
        echo ""
        read -p "Presiona Enter para continuar..."
    fi
fi

# Probar monitoreo
echo ""
echo "🧪 Probando monitoreo..."
/usr/local/bin/vpc-monitor

if [ -f /var/log/monitoring/monitor.log ]; then
    echo "✅ Monitoreo funcionando correctamente"
else
    echo "❌ Error en el monitoreo"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ Configuración completada"
echo "========================================="
echo ""
echo "📊 Monitoreo configurado:"
echo "  - Verificación cada hora"
echo "  - Reporte diario a las 8:00 AM"

if [ "$SEND_EMAIL" = "true" ]; then
    echo "  - Alertas por email a: $EMAIL_TO"
fi

echo ""
echo "📁 Logs del monitoreo:"
echo "  /var/log/monitoring/monitor.log      (log de monitoreo)"
echo "  /var/log/monitoring/alerts.log       (log de alertas)"
echo "  /var/log/monitoring/daily-report-*.log  (reportes diarios)"
echo ""
echo "🔧 Gestión:"
echo "  - Ver log de monitoreo: tail -f /var/log/monitoring/monitor.log"
echo "  - Ver alertas: tail -f /var/log/monitoring/alerts.log"
echo "  - Ejecutar manualmente: /usr/local/bin/vpc-monitor"
echo "  - Reporte diario: /usr/local/bin/vpc-daily-report"
echo "  - Editar configuración: nano /etc/cron.d/vpc-monitoring"
echo ""
echo "📧 Para configurar email:"
echo "  ./setup-email-alerts.sh"
echo ""
