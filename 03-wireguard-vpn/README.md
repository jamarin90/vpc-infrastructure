# WireGuard VPN

Configuración de WireGuard como servidor VPN personal. WireGuard es moderno, rápido, seguro y muy simple de configurar.

## 📋 Requisitos previos

- ✅ Paso 1 completado (SSH + Firewall)
- ✅ IP pública del servidor
- ✅ Puerto UDP 51820 abierto en firewall (el script lo configura)

## 🌟 ¿Por qué WireGuard?

- **Rápido**: Más rápido que OpenVPN
- **Seguro**: Criptografía moderna
- **Simple**: Configuración mínima
- **Eficiente**: Bajo consumo de CPU/batería
- **Cross-platform**: Windows, Mac, Linux, iOS, Android

## 📋 Pasos de instalación

### 1. Subir archivos al servidor

```bash
# Desde tu máquina local
scp -r 03-wireguard-vpn/ root@tu-servidor:/root/
```

### 2. Conectarte al servidor

```bash
ssh root@tu-servidor
cd /root/03-wireguard-vpn
```

### 3. Ejecutar instalación

```bash
chmod +x install.sh add-client.sh remove-client.sh
./install.sh
```

Este script:
- Instala WireGuard
- Habilita IP forwarding
- Genera llaves del servidor
- Crea configuración base
- Abre puerto en firewall
- Arranca el servicio

### 4. Agregar clientes (dispositivos)

```bash
# Agregar tu laptop
./add-client.sh laptop

# Agregar tu teléfono
./add-client.sh phone

# Agregar tablet
./add-client.sh tablet
```

Cada comando genera:
- Configuración del cliente
- Código QR (para móviles)
- Archivo `.conf` descargable

### 5. Descargar configuración del cliente

```bash
# Desde tu máquina local
scp root@tu-servidor:/root/wireguard-clients/laptop.conf ~/
```

### 6. Configurar cliente

#### Linux/Mac:
```bash
# Instalar WireGuard
# Ubuntu/Debian: apt install wireguard
# Mac: brew install wireguard-tools

# Copiar configuración
sudo cp laptop.conf /etc/wireguard/wg0.conf

# Conectar
sudo wg-quick up wg0

# Desconectar
sudo wg-quick down wg0

# Arranque automático
sudo systemctl enable wg-quick@wg0
```

#### Windows:
1. Descargar WireGuard desde: https://www.wireguard.com/install/
2. Abrir WireGuard GUI
3. Click en "Add Tunnel" > "Import from file"
4. Seleccionar el archivo `.conf`
5. Click en "Activate"

#### iOS/Android:
1. Instalar WireGuard desde App Store / Play Store
2. Abrir app
3. Click en "+" > "Create from QR code"
4. Escanear el QR que mostró el script

## 🔧 Gestión de clientes

### Ver clientes conectados

```bash
# En el servidor
wg show

# Ver solo IPs conectadas
wg show wg0 endpoints

# Ver tráfico
wg show wg0 transfer
```

### Agregar más clientes

```bash
./add-client.sh nombre-cliente
```

### Eliminar un cliente

```bash
./remove-client.sh nombre-cliente
```

### Listar todos los clientes

```bash
ls -1 ~/wireguard-clients/
```

## 🔍 Verificación

### En el servidor

```bash
# Estado del servicio
systemctl status wg-quick@wg0

# Ver configuración activa
wg show

# Ver interfaces de red
ip addr show wg0

# Logs
journalctl -u wg-quick@wg0 -f
```

### En el cliente (una vez conectado)

```bash
# Linux/Mac
wg show

# Verificar IP asignada
ip addr show wg0

# Verificar conectividad
ping 10.8.0.1  # IP del servidor en la VPN

# Ver tu IP pública (debe ser la del servidor)
curl ifconfig.me
```

## 🌐 Casos de uso

### 1. Navegación segura en WiFi público

Conecta a WireGuard cuando estés en cafeterías, aeropuertos, etc.
Todo tu tráfico irá cifrado a tu servidor.

### 2. Acceso a servicios del servidor

Accede a servicios sin exponer puertos públicamente:
- Bases de datos
- Paneles de administración
- Servicios internos

### 3. Bypass de restricciones

Accede a contenido como si estuvieras en la ubicación de tu servidor.

### 4. Split tunneling

Configura qué tráfico va por VPN y cuál no (ver sección avanzada).

## 🆘 Troubleshooting

### No puedo conectar

```bash
# En el servidor, verificar firewall
ufw status | grep 51820

# Debe mostrar:
# 51820/udp    ALLOW       Anywhere

# Verificar que WireGuard está corriendo
systemctl status wg-quick@wg0

# Ver logs
journalctl -u wg-quick@wg0 -n 50
```

### Conecta pero no hay internet

```bash
# En el servidor, verificar IP forwarding
sysctl net.ipv4.ip_forward
# Debe mostrar: net.ipv4.ip_forward = 1

# Verificar reglas de NAT
iptables -t nat -L POSTROUTING -n -v
```

### Rendimiento lento

```bash
# Verificar MTU
# En el cliente, edita el .conf y ajusta:
MTU = 1420  # Prueba valores entre 1280-1420

# Verificar latencia
ping 10.8.0.1
```

### Cliente no recibe QR code

```bash
# Instalar qrencode en el servidor
apt install qrencode

# Generar QR manualmente
qrencode -t ansiutf8 < ~/wireguard-clients/cliente.conf
```

## 📊 Comandos útiles

```bash
# Ver clientes conectados en tiempo real
watch -n 1 wg show

# Ver estadísticas detalladas
wg show all

# Reiniciar WireGuard
systemctl restart wg-quick@wg0

# Ver logs en tiempo real
journalctl -u wg-quick@wg0 -f

# Verificar configuración
wg-quick strip wg0

# Backup de configuración
tar -czf wireguard-backup.tar.gz /etc/wireguard ~/wireguard-clients
```

## 🔐 Seguridad

### Mejores prácticas

1. **Usa claves únicas** por dispositivo (el script lo hace automáticamente)
2. **Revoca acceso** de dispositivos perdidos inmediatamente
3. **Monitorea conexiones** regularmente
4. **Actualiza WireGuard** periódicamente
5. **No compartas configuraciones** entre dispositivos

### Revocar acceso de un dispositivo perdido

```bash
# Eliminar cliente
./remove-client.sh dispositivo-perdido

# Reiniciar WireGuard
systemctl restart wg-quick@wg0

# Verificar que ya no está
wg show
```

## ⚙️ Configuración avanzada

### Cambiar puerto

Edita `/etc/wireguard/wg0.conf`:
```ini
[Interface]
ListenPort = 51821  # Cambiar de 51820 a otro puerto
```

Actualiza firewall:
```bash
ufw delete allow 51820/udp
ufw allow 51821/udp
systemctl restart wg-quick@wg0
```

### Split tunneling (solo ciertos sitios por VPN)

En la configuración del cliente, cambia:
```ini
# En vez de:
AllowedIPs = 0.0.0.0/0, ::/0

# Usa solo las IPs que necesites:
AllowedIPs = 10.8.0.0/24, 192.168.1.0/24
```

### Rutas específicas

```ini
# Solo rutear tráfico a redes privadas del servidor
AllowedIPs = 10.8.0.0/24, 172.16.0.0/12, 192.168.0.0/16
```

### DNS personalizado

En la configuración del cliente:
```ini
[Interface]
DNS = 1.1.1.1, 1.0.0.1  # Cloudflare
# DNS = 8.8.8.8, 8.8.4.4  # Google
# DNS = 10.8.0.1  # Usar DNS del servidor
```

### IPv6

Si tu servidor tiene IPv6, edita `/etc/wireguard/wg0.conf`:
```ini
[Interface]
Address = 10.8.0.1/24, fd42:42:42::1/64
```

## 📁 Estructura de archivos

```
/etc/wireguard/
├── wg0.conf            # Configuración del servidor
├── private.key         # Llave privada del servidor
└── public.key          # Llave pública del servidor

~/wireguard-clients/
├── laptop.conf         # Configuración cliente laptop
├── phone.conf          # Configuración cliente phone
└── tablet.conf         # Configuración cliente tablet
```

## 🔄 Backup y restauración

### Backup

```bash
# En el servidor
tar -czf wireguard-backup-$(date +%Y%m%d).tar.gz \
    /etc/wireguard \
    ~/wireguard-clients

# Descargar a tu máquina local
scp root@servidor:~/wireguard-backup-*.tar.gz ~/backups/
```

### Restauración

```bash
# Subir backup al servidor
scp ~/backups/wireguard-backup-*.tar.gz root@servidor:~/

# En el servidor
tar -xzf wireguard-backup-*.tar.gz -C /
systemctl restart wg-quick@wg0
```

## 📈 Monitoreo

### Ver uso de ancho de banda

```bash
# Por cliente
wg show wg0 transfer

# Instalar herramienta de monitoreo (opcional)
apt install vnstat
vnstat -i wg0
```

### Alertas de conexión

Crea script en `/usr/local/bin/wg-notify.sh`:
```bash
#!/bin/bash
CLIENTS=$(wg show wg0 peers | wc -l)
echo "Clientes conectados: $CLIENTS"
```

Agregar a cron:
```bash
*/5 * * * * /usr/local/bin/wg-notify.sh
```

## 🎯 Próximos pasos

Una vez que tengas WireGuard funcionando:
1. Prueba conectar desde diferentes dispositivos
2. Verifica que tu IP pública cambia al conectar
3. Accede a servicios internos del servidor sin exponerlos
4. Configura Docker y accede a tus apps vía VPN
