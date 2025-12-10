# Monitoreo del servidor

Sistema completo de monitoreo para tu VPC. Incluye múltiples opciones según tus necesidades.

## 🎯 Opciones disponibles

### Opción 1: Monitoreo básico (RECOMENDADO para empezar)
- ✅ **Sin instalación adicional** - usa herramientas del sistema
- ✅ Script de monitoreo personalizado
- ✅ Reportes por email
- ✅ Alertas simples
- ⚡ **Tiempo de setup:** 5 minutos

### Opción 2: Netdata (Visual y fácil)
- ✅ Dashboard en tiempo real
- ✅ Instalación con 1 comando
- ✅ **Muy bajo consumo** de recursos
- ✅ Miles de métricas automáticas
- 🌐 Acceso web (protegido con Nginx + SSL)
- ⚡ **Tiempo de setup:** 15 minutos

### Opción 3: Prometheus + Grafana (Profesional)
- ✅ **Solución enterprise**
- ✅ Dashboards personalizables
- ✅ Alertas avanzadas
- ✅ Retención histórica de datos
- ⚠️ Más recursos (RAM, CPU)
- ⚡ **Tiempo de setup:** 30-45 minutos

## 📊 Comparación de opciones

| Característica | Básico | Netdata | Prometheus + Grafana |
|---------------|--------|---------|---------------------|
| Recursos | Mínimo | Bajo | Medio-Alto |
| Instalación | 5 min | 15 min | 45 min |
| Interfaz visual | ❌ | ✅ | ✅ |
| Tiempo real | ✅ | ✅ | ✅ |
| Histórico largo | ❌ | Limitado | ✅ |
| Alertas | Email | Limitadas | Avanzadas |
| Dashboards | CLI | Fijos | Personalizables |
| Complejidad | Muy bajo | Bajo | Medio |

## 🚀 Opción 1: Monitoreo Básico

Usa herramientas del sistema sin instalar nada adicional.

### ¿Qué monitorea?

- ✅ CPU, RAM, Disco
- ✅ Servicios (Nginx, SSH, WireGuard, Docker)
- ✅ Intentos de intrusión (fail2ban)
- ✅ Certificados SSL (expiración)
- ✅ Clientes VPN conectados
- ✅ Tráfico de red
- ✅ Logs de errores

### Instalación

```bash
cd 04-monitoring
chmod +x *.sh
./basic-monitor.sh
```

Este script genera un reporte completo que puedes:
- Ver en terminal
- Guardar en archivo
- Enviar por email (configurando)
- Ejecutar en cron (automático)

### Configurar monitoreo automático

```bash
# Ejecutar cada hora y enviar reporte si hay problemas
./setup-basic-monitoring.sh
```

## 🎨 Opción 2: Netdata (RECOMENDADO)

Dashboard visual en tiempo real con instalación ultra-simple.

### ¿Por qué Netdata?

- 🚀 **1 comando de instalación**
- 💻 Dashboard hermoso en tiempo real
- 📊 Miles de métricas automáticas
- 🔋 Muy bajo consumo (40MB RAM)
- 🐳 Monitorea contenedores Docker automáticamente
- 🔔 Alertas integradas

### Vista previa

Netdata muestra:
- CPU por core en tiempo real
- RAM y swap detallado
- Disco I/O y espacio
- Red (tráfico, paquetes, errores)
- Procesos top
- Docker containers
- Nginx requests
- Temperatura del sistema
- Y mucho más...

### Instalación

```bash
cd 04-monitoring
./install-netdata.sh
```

El script:
1. Instala Netdata
2. Lo configura en el puerto 19999
3. Configura Nginx como reverse proxy
4. Obtiene certificado SSL
5. Configura autenticación básica

### Acceso

```bash
# Acceso local (desde VPN)
http://10.8.0.1:19999

# Acceso público (con SSL y contraseña)
https://monitor.tu-dominio.com
```

### Personalización

```bash
# Archivo de configuración
nano /etc/netdata/netdata.conf

# Deshabilitar módulos que no necesites
nano /etc/netdata/python.d.conf

# Ver status
systemctl status netdata
```

## 🏢 Opción 3: Prometheus + Grafana

Solución profesional para monitoreo avanzado.

### ¿Por qué Prometheus + Grafana?

- 📈 Dashboards ultra personalizables
- 🗄️ Base de datos de series temporales
- 🔔 Sistema de alertas avanzado
- 📊 Consultas PromQL potentes
- 🔌 Miles de exportadores disponibles
- 🌍 Estándar de la industria

### Arquitectura

```
[Node Exporter] ← Métricas del sistema
[cAdvisor] ← Métricas de Docker
[Nginx Exporter] ← Métricas de Nginx
     ↓
[Prometheus] ← Recolecta y almacena
     ↓
[Grafana] ← Visualización
```

### Instalación

```bash
cd 04-monitoring
./install-prometheus-grafana.sh
```

El script instala:
- Prometheus (métricas)
- Grafana (visualización)
- Node Exporter (sistema)
- cAdvisor (Docker)
- Nginx Exporter (web)
- AlertManager (alertas)

Todo en Docker Compose para fácil gestión.

### Acceso

```bash
# Grafana (interfaz principal)
https://grafana.tu-dominio.com
Usuario: admin
Password: (generada al instalar)

# Prometheus (queries)
https://prometheus.tu-dominio.com
```

### Dashboards incluidos

1. **System Overview** - CPU, RAM, Disco, Red
2. **Docker Monitoring** - Contenedores, volúmenes, redes
3. **Nginx Stats** - Requests, códigos, latencia
4. **WireGuard VPN** - Clientes, tráfico
5. **Security Dashboard** - fail2ban, intentos SSH

### Alertas configuradas

- ✅ CPU > 80% por 5 minutos
- ✅ RAM > 90% por 5 minutos
- ✅ Disco > 85%
- ✅ Servicio caído
- ✅ Certificado SSL expira en < 7 días
- ✅ Sin conexión VPN por 30 minutos

## 📧 Alertas por email

Todas las opciones pueden enviar alertas por email.

### Configurar email

```bash
./setup-email-alerts.sh
```

Te pedirá:
- Email destino
- SMTP server (Gmail, SendGrid, etc.)
- Credenciales

### Alertas que enviará

- 🔴 Servicio caído
- 🟡 Recursos al límite
- 🟠 Certificado por expirar
- 🔵 Intentos de intrusión masivos
- ⚪ Reporte diario de status

## 📱 Telegram/Slack/Discord (Opcional)

Además de email, puedes recibir alertas en:

### Telegram

```bash
./setup-telegram-alerts.sh
```

### Slack

```bash
./setup-slack-alerts.sh
```

### Discord

```bash
./setup-discord-alerts.sh
```

## 🔍 Verificación

```bash
# Verificar servicios de monitoreo
./verify-monitoring.sh
```

## 📊 Scripts de reportes

### Reporte diario

```bash
# Genera reporte completo del día
./daily-report.sh
```

Incluye:
- Uptime
- Uso promedio de recursos
- Peticiones web (top IPs, URLs)
- Intentos de intrusión
- Clientes VPN conectados
- Errores en logs
- Estado de certificados SSL

### Reporte semanal

```bash
./weekly-report.sh
```

### Reporte mensual

```bash
./monthly-report.sh
```

## 🎯 Mi recomendación

### Para empezar: **Netdata**

Es el mejor balance entre facilidad y funcionalidad:

```bash
cd 04-monitoring
./install-netdata.sh
```

En 15 minutos tienes un dashboard profesional sin complicaciones.

### Luego, si necesitas más: **Prometheus + Grafana**

Cuando necesites:
- Dashboards personalizados
- Alertas complejas
- Retención de datos a largo plazo
- Múltiples servidores

```bash
./install-prometheus-grafana.sh
```

### Siempre útil: **Monitoreo básico**

Configura el monitoreo básico aunque uses Netdata/Grafana:

```bash
./setup-basic-monitoring.sh
```

Te envía emails si algo crítico falla.

## 📁 Estructura de archivos

```
04-monitoring/
├── README.md                          # Esta guía
│
├── basic-monitor.sh                   # Monitoreo básico
├── setup-basic-monitoring.sh          # Configurar auto-monitoreo
│
├── install-netdata.sh                 # Instalar Netdata
├── netdata-config.conf                # Configuración Netdata
│
├── install-prometheus-grafana.sh      # Instalar Prom + Grafana
├── docker-compose-monitoring.yml      # Stack completo
├── prometheus.yml                     # Config Prometheus
├── grafana-dashboards/                # Dashboards pre-configurados
│   ├── system.json
│   ├── docker.json
│   ├── nginx.json
│   └── security.json
│
├── setup-email-alerts.sh              # Configurar email
├── setup-telegram-alerts.sh           # Telegram bot
├── setup-slack-alerts.sh              # Slack webhook
├── setup-discord-alerts.sh            # Discord webhook
│
├── daily-report.sh                    # Reporte diario
├── weekly-report.sh                   # Reporte semanal
├── monthly-report.sh                  # Reporte mensual
│
└── verify-monitoring.sh               # Verificar todo
```

## 💡 Tips

### Acceso seguro a dashboards

Siempre usa:
1. **SSL (HTTPS)** - Ya configurado con Let's Encrypt
2. **Autenticación** - Usuario y contraseña
3. **VPN** - Accede solo desde tu VPN (más seguro)
4. **Firewall** - No expongas puertos innecesarios

### Optimizar recursos

Si tu servidor tiene poca RAM:
- Usa Netdata en vez de Grafana
- Reduce retención de métricas
- Deshabilita módulos que no uses

### Retención de datos

- **Netdata**: 1 hora (personalizable)
- **Prometheus**: 15 días (personalizable)
- **Grafana**: Según Prometheus

### Backup de dashboards

```bash
# Exportar dashboards de Grafana
./backup-dashboards.sh
```

## 🆘 Troubleshooting

### Netdata no arranca

```bash
systemctl status netdata
journalctl -u netdata -n 50
```

### Grafana no carga

```bash
docker-compose logs grafana
```

### Prometheus sin métricas

```bash
# Verificar exportadores
curl http://localhost:9100/metrics  # Node Exporter
curl http://localhost:9090/metrics  # Prometheus
```

### Alto consumo de recursos

```bash
# Ver consumo de Netdata
ps aux | grep netdata

# Ver consumo de contenedores
docker stats
```

## 📚 Recursos

- [Netdata Docs](https://learn.netdata.cloud/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [Dashboards públicos de Grafana](https://grafana.com/grafana/dashboards/)

## 🎓 Próximos pasos

1. Instala Netdata para empezar
2. Configura alertas por email
3. Revisa el dashboard diariamente
4. Ajusta umbrales de alertas
5. Cuando necesites más, migra a Prometheus + Grafana
