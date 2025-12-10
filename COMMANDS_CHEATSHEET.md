# Hoja de referencia rápida de comandos

Comandos más útiles para gestionar tu VPC. Guarda este archivo para referencia rápida.

## 🔐 SSH + Firewall

### Fail2ban

```bash
# Ver estado
systemctl status fail2ban

# Ver jails activos
fail2ban-client status

# Ver estadísticas de SSH
fail2ban-client status sshd

# Ver IPs baneadas
fail2ban-client status sshd | grep "Banned IP"

# Desbanear una IP
fail2ban-client set sshd unbanip 1.2.3.4

# Ver logs
tail -f /var/log/fail2ban.log

# Reiniciar
systemctl restart fail2ban
```

### UFW (Firewall)

```bash
# Ver estado
ufw status verbose

# Ver reglas numeradas
ufw status numbered

# Permitir puerto
ufw allow 8080/tcp

# Permitir desde IP específica
ufw allow from 1.2.3.4 to any port 22

# Eliminar regla
ufw delete <número>
ufw delete allow 8080/tcp

# Deshabilitar/habilitar
ufw disable
ufw enable

# Reset (cuidado!)
ufw reset
```

### SSH

```bash
# Ver intentos de login
tail -f /var/log/auth.log

# Ver solo intentos fallidos
grep "Failed password" /var/log/auth.log

# Ver conexiones activas
who
w

# Verificar configuración sin aplicar
sshd -t

# Reiniciar SSH
systemctl restart sshd

# Ver logs en tiempo real
journalctl -u ssh -f
```

## 🌐 Nginx

### Gestión del servicio

```bash
# Estado
systemctl status nginx

# Iniciar/detener/reiniciar
systemctl start nginx
systemctl stop nginx
systemctl restart nginx

# Recargar configuración (sin downtime)
systemctl reload nginx

# Habilitar inicio automático
systemctl enable nginx
```

### Configuración

```bash
# Probar configuración sin aplicar
nginx -t

# Ver configuración activa
nginx -T

# Ver sitios disponibles
ls /etc/nginx/sites-available/

# Ver sitios habilitados
ls /etc/nginx/sites-enabled/

# Habilitar sitio
ln -s /etc/nginx/sites-available/mi-sitio.conf /etc/nginx/sites-enabled/

# Deshabilitar sitio
rm /etc/nginx/sites-enabled/mi-sitio.conf
systemctl reload nginx
```

### Logs

```bash
# Ver logs de acceso
tail -f /var/log/nginx/access.log

# Ver logs de error
tail -f /var/log/nginx/error.log

# Ver logs de un sitio específico
tail -f /var/log/nginx/mi-sitio-access.log

# Buscar errores 404
grep "404" /var/log/nginx/access.log

# Buscar errores 500
grep "500" /var/log/nginx/access.log

# Ver IPs más frecuentes
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head -20
```

### Estadísticas

```bash
# Conexiones activas
ss -tulpn | grep nginx

# Estadísticas de Nginx
curl http://localhost/nginx_status  # Si está configurado
```

## 🔒 Let's Encrypt (Certbot)

### Gestión de certificados

```bash
# Listar certificados
certbot certificates

# Renovar certificados
certbot renew

# Renovar de forma forzada
certbot renew --force-renewal

# Test de renovación (no renueva realmente)
certbot renew --dry-run

# Obtener nuevo certificado
certbot --nginx -d dominio.com

# Obtener certificado con múltiples dominios
certbot --nginx -d dominio.com -d www.dominio.com -d api.dominio.com

# Revocar certificado
certbot revoke --cert-name dominio.com

# Eliminar certificado
certbot delete --cert-name dominio.com
```

### Información

```bash
# Ver detalles de un certificado
certbot certificates -d dominio.com

# Ver cuándo expira
openssl x509 -noout -dates -in /etc/letsencrypt/live/dominio.com/cert.pem

# Verificar certificado
echo | openssl s_client -connect dominio.com:443 2>/dev/null | openssl x509 -noout -dates

# Ver logs
tail -f /var/log/letsencrypt/letsencrypt.log
```

### Timer de renovación

```bash
# Ver estado del timer
systemctl status certbot.timer

# Ver próxima ejecución
systemctl list-timers certbot.timer

# Habilitar/deshabilitar
systemctl enable certbot.timer
systemctl disable certbot.timer
```

## 🔐 WireGuard VPN

### Gestión del servicio

```bash
# Estado
systemctl status wg-quick@wg0

# Iniciar/detener/reiniciar
systemctl start wg-quick@wg0
systemctl stop wg-quick@wg0
systemctl restart wg-quick@wg0

# Habilitar inicio automático
systemctl enable wg-quick@wg0

# Logs
journalctl -u wg-quick@wg0 -f
```

### Gestión de clientes

```bash
# Ver configuración activa
wg show

# Ver solo peers (clientes)
wg show wg0 peers

# Ver endpoints (IPs conectadas)
wg show wg0 endpoints

# Ver transferencia de datos
wg show wg0 transfer

# Ver información completa
wg show all

# Ver en tiempo real
watch -n 1 wg show
```

### Scripts personalizados

```bash
# Agregar cliente
cd ~/vpc/03-wireguard-vpn
./add-client.sh nombre-cliente

# Eliminar cliente
./remove-client.sh nombre-cliente

# Listar todos los clientes
./list-clients.sh

# Verificar configuración
./verify.sh
```

### Cliente (en tu laptop/desktop)

```bash
# Conectar
sudo wg-quick up nombre-config

# Desconectar
sudo wg-quick down nombre-config

# Ver estado
wg show

# Ver IP asignada
ip addr show wg0

# Ping al servidor VPN
ping 10.8.0.1

# Ver tu IP pública (debe ser la del servidor)
curl ifconfig.me
```

## 🐳 Docker

### Gestión de contenedores

```bash
# Listar contenedores corriendo
docker ps

# Listar todos (incluyendo detenidos)
docker ps -a

# Ver logs
docker logs nombre-contenedor
docker logs -f nombre-contenedor  # En tiempo real

# Iniciar/detener/reiniciar
docker start nombre-contenedor
docker stop nombre-contenedor
docker restart nombre-contenedor

# Ejecutar comando en contenedor
docker exec -it nombre-contenedor bash
docker exec nombre-contenedor ls /app

# Ver estadísticas
docker stats

# Eliminar contenedor
docker rm nombre-contenedor
docker rm -f nombre-contenedor  # Forzar
```

### Docker Compose

```bash
# Iniciar servicios
docker-compose up -d

# Ver logs
docker-compose logs
docker-compose logs -f
docker-compose logs -f servicio-especifico

# Detener servicios
docker-compose down

# Detener y eliminar volúmenes
docker-compose down -v

# Ver estado
docker-compose ps

# Reiniciar servicio específico
docker-compose restart servicio

# Reconstruir y reiniciar
docker-compose up -d --build

# Ejecutar comando en servicio
docker-compose exec servicio bash
```

### Limpieza

```bash
# Eliminar contenedores detenidos
docker container prune

# Eliminar imágenes no usadas
docker image prune

# Eliminar todo lo no usado
docker system prune

# Eliminar todo (incluyendo volúmenes)
docker system prune -a --volumes

# Ver uso de disco
docker system df
```

## 📊 Sistema

### Monitoreo

```bash
# Uso de CPU y memoria
htop
top

# Uso de disco
df -h
du -sh /var/log/*

# Procesos escuchando en puertos
ss -tulpn
netstat -tulpn

# Ver procesos de un usuario
ps aux | grep nginx
ps aux | grep wireguard

# Espacio en disco por directorio
du -h --max-depth=1 /var/ | sort -hr
```

### Logs del sistema

```bash
# Ver todos los logs
journalctl

# Logs desde el boot
journalctl -b

# Logs de un servicio
journalctl -u nginx
journalctl -u ssh

# Logs en tiempo real
journalctl -f

# Logs de las últimas N líneas
journalctl -n 50

# Logs entre fechas
journalctl --since "2024-01-01" --until "2024-01-31"

# Logs de errores
journalctl -p err
```

### Actualizaciones

```bash
# Actualizar lista de paquetes
apt update

# Actualizar paquetes
apt upgrade

# Actualizar todo (incluye cambios de dependencias)
apt full-upgrade

# Ver paquetes que se pueden actualizar
apt list --upgradable

# Buscar paquete
apt search nombre

# Información de paquete
apt show nombre

# Autoremover paquetes no necesarios
apt autoremove
```

### Red

```bash
# Ver IP pública
curl ifconfig.me
curl icanhazip.com

# Ver IPs del servidor
ip addr show
hostname -I

# Ver rutas
ip route

# Ver DNS
cat /etc/resolv.conf

# Test de DNS
nslookup google.com
dig google.com

# Test de puerto
telnet dominio.com 80
nc -zv dominio.com 443

# Ver conexiones activas
ss -tuln
netstat -tuln
```

## 🔧 Troubleshooting

### Reiniciar todos los servicios

```bash
systemctl restart nginx
systemctl restart fail2ban
systemctl restart wg-quick@wg0
```

### Ver recursos del sistema

```bash
# Memoria
free -h

# CPU
mpstat
lscpu

# Disco
df -h
iostat
```

### Verificar puertos abiertos

```bash
# Desde el servidor
ss -tulpn | grep LISTEN

# Desde fuera (en tu laptop)
nmap TU_IP_SERVIDOR

# Test específico
telnet TU_IP_SERVIDOR 80
nc -zv TU_IP_SERVIDOR 443
```

### Permisos

```bash
# Ver permisos
ls -la /etc/nginx/sites-available/

# Cambiar permisos
chmod 644 archivo
chmod 755 script.sh

# Cambiar dueño
chown usuario:grupo archivo
chown -R usuario:grupo directorio/
```

## 💾 Backup y Restauración

### Backup manual

```bash
# Backup de configuraciones
tar -czf backup-$(date +%Y%m%d).tar.gz \
    /etc/nginx/sites-available \
    /etc/wireguard \
    /etc/fail2ban/jail.local \
    /etc/ssh/sshd_config \
    ~/wireguard-clients

# Backup de base de datos (ejemplo PostgreSQL)
pg_dump midb > backup-db-$(date +%Y%m%d).sql

# Backup de volúmenes Docker
docker run --rm -v nombre-volumen:/data -v $(pwd):/backup \
    alpine tar czf /backup/volumen-backup.tar.gz /data
```

### Restauración

```bash
# Restaurar configuraciones
tar -xzf backup-20240101.tar.gz -C /

# Restaurar base de datos
psql midb < backup-db-20240101.sql
```

## 📚 Alias útiles

Agrega estos a tu `~/.bashrc`:

```bash
# Logs
alias nginx-logs='tail -f /var/log/nginx/access.log'
alias nginx-errors='tail -f /var/log/nginx/error.log'
alias ssl-logs='tail -f /var/log/letsencrypt/letsencrypt.log'

# Status
alias vpn-status='wg show'
alias nginx-status='systemctl status nginx'
alias fw-status='ufw status verbose'

# Docker
alias dps='docker ps'
alias dlog='docker-compose logs -f'
alias dup='docker-compose up -d'
alias ddown='docker-compose down'

# Sistema
alias myip='curl ifconfig.me'
alias ports='ss -tulpn'
```

Luego ejecuta: `source ~/.bashrc`

---

**Tip:** Guarda este archivo en tu favoritos. Es tu referencia rápida para todo! 📌
