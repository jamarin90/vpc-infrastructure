# Configuración de VPC Personal

Guías y scripts completos para configurar tu servidor VPC personal de forma segura y profesional.

## 🎯 ¿Qué incluye este repositorio?

Este repositorio contiene todo lo necesario para configurar un servidor VPC desde cero con las mejores prácticas de seguridad y herramientas modernas:

1. **Seguridad SSH + Firewall** - Protege tu servidor de ataques
2. **Nginx + Let's Encrypt** - Servidor web con SSL gratuito
3. **WireGuard VPN** - VPN personal moderna y rápida
4. **Monitoreo** - Dashboard y alertas (Netdata / Prometheus + Grafana)

## 📋 Requisitos

- Servidor Debian (VPC de Contabo o similar)
- Acceso root o sudo
- Nombre de dominio (para SSL)
- IP pública

## 🚀 Guía de inicio rápido

### Orden de instalación recomendado

```bash
# 1. Seguridad primero (15-20 minutos)
cd 01-ssh-firewall
./install.sh
./setup-firewall.sh
# Aplicar configuración SSH (lee README.md cuidadosamente)

# 2. Servidor web con SSL (20 minutos)
cd ../02-nginx-letsencrypt
./install.sh
./get-ssl-cert.sh tu-dominio.com tu-email@ejemplo.com

# 3. VPN personal (30 minutos)
cd ../03-wireguard-vpn
./install.sh
./add-client.sh mi-laptop

# 4. Monitoreo (15 minutos - Opcional pero recomendado)
cd ../04-monitoring
./install-netdata.sh  # Opción simple y visual
# O: ./install-prometheus-grafana.sh  # Opción profesional
```

## 📁 Estructura del proyecto

```
vpc/
├── README.md                          # Este archivo
├── 01-ssh-firewall/                   # Paso 1: Seguridad
│   ├── README.md                      # Guía detallada
│   ├── install.sh                     # Instalador
│   ├── setup-firewall.sh              # Configuración firewall
│   ├── jail.local                     # Configuración fail2ban
│   ├── sshd_config                    # SSH hardening
│   ├── verify.sh                      # Verificación
│   └── rollback.sh                    # Rollback de emergencia
│
├── 02-nginx-letsencrypt/              # Paso 2: Web + SSL
│   ├── README.md                      # Guía detallada
│   ├── install.sh                     # Instalador Nginx + Certbot
│   ├── get-ssl-cert.sh                # Obtener certificado SSL
│   ├── site-example.conf              # Ejemplo sitio estático
│   ├── docker-proxy-example.conf      # Ejemplos reverse proxy
│   ├── docker-compose-examples.yml    # Ejemplos Docker
│   └── verify.sh                      # Verificación
│
├── 03-wireguard-vpn/                  # Paso 3: VPN
│   ├── README.md                      # Guía detallada
│   ├── install.sh                     # Instalador WireGuard
│   ├── add-client.sh                  # Agregar clientes
│   ├── remove-client.sh               # Eliminar clientes
│   ├── list-clients.sh                # Listar clientes
│   └── verify.sh                      # Verificación
│
└── 04-monitoring/                     # Paso 4: Monitoreo
    ├── README.md                      # Guía detallada (3 opciones)
    ├── basic-monitor.sh               # Monitoreo básico
    ├── setup-basic-monitoring.sh      # Configurar auto-monitoreo
    ├── install-netdata.sh             # Instalar Netdata
    ├── install-prometheus-grafana.sh  # Instalar Prom + Grafana
    ├── docker-compose-monitoring.yml  # Stack completo
    ├── prometheus.yml                 # Config Prometheus
    └── verify-monitoring.sh           # Verificación
```

## 🔐 Paso 1: Seguridad SSH + Firewall

**Objetivo:** Proteger tu servidor de ataques de fuerza bruta y accesos no autorizados.

### ¿Qué hace?

- Instala y configura **fail2ban** (banea IPs con intentos fallidos)
- Configura **ufw** (firewall)
- **Hardening de SSH** (deshabilita passwords, solo llaves)
- Abre puertos necesarios (22, 80, 443)

### Instalación

```bash
cd 01-ssh-firewall
./install.sh
./setup-firewall.sh
```

**⚠️ IMPORTANTE:** Lee el README.md antes de aplicar la configuración SSH. Una mala configuración puede dejarte sin acceso.

### Verificación

```bash
./verify.sh
```

📖 **Documentación completa:** [01-ssh-firewall/README.md](01-ssh-firewall/README.md)

## 🌐 Paso 2: Nginx + Let's Encrypt

**Objetivo:** Servidor web con certificados SSL gratuitos y renovación automática.

### ¿Qué hace?

- Instala **Nginx** como reverse proxy
- Instala **Certbot** (cliente de Let's Encrypt)
- Obtiene certificados SSL gratuitos
- Configura renovación automática (cada 60 días)
- Headers de seguridad optimizados

### Instalación

```bash
cd 02-nginx-letsencrypt

# Instalar Nginx + Certbot
./install.sh

# Obtener certificado SSL
./get-ssl-cert.sh tu-dominio.com tu-email@ejemplo.com
```

### Uso con Docker

Nginx en el host hace reverse proxy a contenedores Docker:

```bash
# Ejemplo: Aplicación Node.js en Docker
docker run -d -p 3000:3000 mi-app

# Nginx hace proxy de dominio.com → localhost:3000
```

Ver ejemplos completos en:
- `docker-proxy-example.conf` - Configuraciones de reverse proxy
- `docker-compose-examples.yml` - Stacks completos (Frontend + Backend + DB)

### Verificación

```bash
./verify.sh

# O manualmente
curl https://tu-dominio.com
certbot certificates
```

📖 **Documentación completa:** [02-nginx-letsencrypt/README.md](02-nginx-letsencrypt/README.md)

## 🔒 Paso 3: WireGuard VPN

**Objetivo:** VPN personal para navegar seguro y acceder a servicios privados.

### ¿Qué hace?

- Instala **WireGuard** (VPN moderna y rápida)
- Configura servidor VPN
- Genera configuraciones para clientes
- Códigos QR para móviles

### Instalación

```bash
cd 03-wireguard-vpn

# Instalar servidor
./install.sh

# Agregar tu laptop
./add-client.sh laptop

# Agregar tu teléfono
./add-client.sh phone
```

### Conectar desde cliente

**Desktop (Linux/Mac):**
```bash
# Descargar configuración
scp root@servidor:~/wireguard-clients/laptop.conf ~/

# Conectar
sudo wg-quick up laptop

# Desconectar
sudo wg-quick down laptop
```

**Móvil (iOS/Android):**
1. Instala WireGuard desde App Store/Play Store
2. Escanea el código QR que mostró el script
3. Activa la conexión

### Gestión de clientes

```bash
./add-client.sh nuevo-cliente      # Agregar
./remove-client.sh cliente-viejo   # Eliminar
./list-clients.sh                  # Listar todos
```

### Verificación

```bash
./verify.sh

# Ver clientes conectados
wg show
```

📖 **Documentación completa:** [03-wireguard-vpn/README.md](03-wireguard-vpn/README.md)

## 📊 Paso 4: Monitoreo

**Objetivo:** Monitorear recursos, servicios y detectar problemas antes de que se conviertan en críticos.

### ¿Qué opciones hay?

**Opción 1: Monitoreo Básico** (5 min)
- Script personalizado sin instalar nada
- Reportes automáticos por email
- Perfecto para empezar

**Opción 2: Netdata** (15 min) - **RECOMENDADO**
- Dashboard visual en tiempo real
- Instalación con 1 comando
- Muy bajo consumo de recursos
- Miles de métricas automáticas

**Opción 3: Prometheus + Grafana** (45 min)
- Solución profesional enterprise
- Dashboards personalizables
- Alertas avanzadas
- Retención histórica de datos

### Instalación rápida (Netdata)

```bash
cd 04-monitoring

# Opción simple: Netdata
./install-netdata.sh

# Opción avanzada: Prometheus + Grafana
./install-prometheus-grafana.sh

# Configurar monitoreo básico con alertas
./setup-basic-monitoring.sh
```

### Lo que monitorea

- ✅ CPU, RAM, Disco en tiempo real
- ✅ Servicios (Nginx, SSH, WireGuard, Docker)
- ✅ Intentos de intrusión (fail2ban)
- ✅ Certificados SSL (expiración)
- ✅ Clientes VPN conectados
- ✅ Tráfico de red
- ✅ Contenedores Docker
- ✅ Logs de errores

### Acceso

**Netdata:**
- Dashboard: `https://monitor.tu-dominio.com`
- O por VPN: `http://10.8.0.1:19999`

**Grafana:**
- Dashboard: `https://grafana.tu-dominio.com`
- Usuario: admin
- Password: (generada al instalar)

### Verificación

```bash
./verify-monitoring.sh

# Ver reporte básico
./basic-monitor.sh
```

📖 **Documentación completa:** [04-monitoring/README.md](04-monitoring/README.md)

## 🎯 Casos de uso completos

### 1. Hosting de aplicación web con Docker

```bash
# 1. App en Docker
docker run -d -p 3000:3000 --name mi-app mi-imagen

# 2. Configurar Nginx (usar docker-proxy-example.conf)
nano /etc/nginx/sites-available/app.conf
# Configurar proxy_pass http://localhost:3000

# 3. Obtener SSL
certbot --nginx -d app.tu-dominio.com

# 4. ¡Listo! https://app.tu-dominio.com
```

### 2. Servicios internos accesibles solo por VPN

```bash
# 1. Servicio que NO quieres exponer públicamente
docker run -d -p 127.0.0.1:5432:5432 postgres

# 2. Conecta a VPN
wg-quick up laptop

# 3. Accede al servicio
psql -h 10.8.0.1 -U usuario

# Sin VPN = inaccesible
# Con VPN = acceso total
```

### 3. Múltiples sitios con SSL

```bash
# blog.tu-dominio.com
./get-ssl-cert.sh blog.tu-dominio.com email@ejemplo.com

# api.tu-dominio.com
./get-ssl-cert.sh api.tu-dominio.com email@ejemplo.com

# app.tu-dominio.com
./get-ssl-cert.sh app.tu-dominio.com email@ejemplo.com

# Todos con SSL gratuito y renovación automática
```

## 🔍 Verificación completa del sistema

```bash
# SSH + Firewall
cd 01-ssh-firewall && ./verify.sh

# Nginx + SSL
cd ../02-nginx-letsencrypt && ./verify.sh

# WireGuard VPN
cd ../03-wireguard-vpn && ./verify.sh

# Monitoreo (si lo instalaste)
cd ../04-monitoring && ./verify-monitoring.sh
```

## 🆘 Solución de problemas

### SSH: Me quedé sin acceso

Si todavía tienes una sesión abierta:
```bash
cd 01-ssh-firewall
./rollback.sh
```

Si no tienes acceso, usa la consola del proveedor (Contabo) para restaurar.

### Nginx: Certificado SSL no funciona

```bash
# Ver logs de Let's Encrypt
less /var/log/letsencrypt/letsencrypt.log

# Problemas comunes:
# - Dominio no apunta al servidor: dig tu-dominio.com
# - Puertos cerrados: ufw status | grep -E '80|443'
# - Límite de tasa: esperar 7 días o usar --staging
```

### WireGuard: No hay internet en la VPN

```bash
# Verificar IP forwarding
sysctl net.ipv4.ip_forward
# Debe ser 1

# Verificar reglas NAT
iptables -t nat -L POSTROUTING

# Reiniciar WireGuard
systemctl restart wg-quick@wg0
```

## 📚 Recursos adicionales

### Documentación oficial
- [WireGuard](https://www.wireguard.com/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Nginx](https://nginx.org/en/docs/)
- [Fail2ban](https://www.fail2ban.org/)

### Herramientas útiles
- [SSL Test](https://www.ssllabs.com/ssltest/) - Verificar seguridad SSL
- [Security Headers](https://securityheaders.com/) - Verificar headers de seguridad
- [DNSChecker](https://dnschecker.org/) - Verificar DNS
- [CanYouSeeMe](https://canyouseeme.org/) - Verificar puertos abiertos

## 🔄 Mantenimiento

### Actualizaciones del sistema

```bash
# Actualizar paquetes
apt update && apt upgrade -y

# Reiniciar servicios si es necesario
systemctl restart nginx
systemctl restart wg-quick@wg0
```

### Renovación de certificados SSL

Automática cada 60 días, pero puedes forzar:
```bash
certbot renew --dry-run  # Probar
certbot renew            # Renovar ahora
```

### Backup

```bash
# Backup de configuraciones importantes
tar -czf backup-$(date +%Y%m%d).tar.gz \
    /etc/nginx/sites-available \
    /etc/wireguard \
    /etc/fail2ban/jail.local \
    /etc/ssh/sshd_config \
    ~/wireguard-clients

# Descargar a tu máquina
scp root@servidor:~/backup-*.tar.gz ~/backups/
```

## 🚀 Próximos pasos

Una vez que tengas todo configurado, puedes:

1. **Montar aplicaciones en Docker** detrás de Nginx
2. **Configurar CI/CD** para deployment automático
3. **Agregar monitoreo** (Prometheus + Grafana)
4. **Bases de datos** accesibles solo por VPN
5. **Servicios adicionales** según tus necesidades

## ⚠️ Advertencias importantes

1. **Backups:** Siempre haz backup antes de cambios importantes
2. **Testing:** Mantén una sesión SSH abierta al hacer cambios
3. **Seguridad:** No compartas llaves SSH o configuraciones VPN
4. **DNS:** Verifica que tu dominio apunta al servidor antes de SSL
5. **Firewall:** Ten cuidado al modificar reglas de firewall

## 📝 Notas

- Todos los scripts están probados en **Debian 11/12**
- Compatible con Ubuntu 20.04/22.04
- Adaptable a otros proveedores (AWS, DigitalOcean, etc.)
- Los scripts piden confirmación antes de cambios importantes
- Incluyen verificación y rollback cuando es posible

## 🤝 Contribuciones

Si encuentras errores o mejoras, siéntete libre de crear un issue o pull request.

## 📄 Licencia

MIT - Usa libremente para tus proyectos personales o comerciales.

---

**¡Disfruta tu VPC seguro y profesional!** 🎉

Si tienes preguntas, revisa los README.md de cada sección para documentación detallada.
