# Seguridad SSH + Firewall

Este directorio contiene scripts y configuraciones para asegurar el acceso SSH y configurar el firewall en tu servidor Debian.

## ⚠️ IMPORTANTE - Leer antes de ejecutar

**RIESGO:** Una mala configuración puede dejarte sin acceso al servidor.
- **Mantén una sesión SSH abierta** mientras pruebas
- **Verifica que tienes acceso con llaves SSH** antes de deshabilitar passwords
- Haz backup de configuraciones originales

## 📋 Pasos de instalación

### 1. Subir archivos al servidor

```bash
# Desde tu máquina local
scp -r 01-ssh-firewall/ root@tu-servidor:/root/
```

### 2. Conectarte al servidor

```bash
ssh root@tu-servidor
cd /root/01-ssh-firewall
```

### 3. Verificar que tienes llaves SSH configuradas

```bash
# En el servidor, verifica que existe:
ls -la ~/.ssh/authorized_keys
# Debe mostrar tu llave pública
```

### 4. Ejecutar instalación (como root)

```bash
chmod +x install.sh setup-firewall.sh
./install.sh
```

### 5. Configurar firewall

**⚠️ IMPORTANTE:** Antes de ejecutar, edita `setup-firewall.sh` si quieres:
- Cambiar el puerto SSH (por defecto deja el 22)
- Agregar tu IP específica para mayor seguridad
- Abrir otros puertos que necesites

```bash
./setup-firewall.sh
```

### 6. Aplicar configuración SSH

```bash
# Backup de configuración actual
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Copiar nueva configuración
cp sshd_config /etc/ssh/sshd_config

# IMPORTANTE: Verifica la configuración antes de reiniciar
sshd -t

# Si no hay errores, reinicia (mantén sesión abierta!)
systemctl restart sshd
```

### 7. Probar acceso en nueva terminal

**NO CIERRES tu sesión actual todavía**. Abre una nueva terminal y prueba:

```bash
ssh root@tu-servidor
```

Si funciona, ¡listo! Si no, usa tu sesión actual para corregir.

## 🔧 Qué hace cada componente

### install.sh
- Actualiza el sistema
- Instala fail2ban y ufw
- Configura fail2ban para SSH

### sshd_config
- Deshabilita login con password (solo llaves SSH)
- Deshabilita root login con password
- Configura timeouts
- Limita intentos de autenticación
- Desactiva forwarding innecesario

### setup-firewall.sh
- Configura ufw (firewall)
- Permite SSH
- Permite HTTP (80) y HTTPS (443) para futuros servicios
- Activa el firewall

### jail.local
- Configuración de fail2ban para SSH
- Banea IPs con 5 intentos fallidos en 10 minutos
- Ban de 1 hora (configurable)

## 🔍 Verificar que todo funciona

```bash
# Estado de fail2ban
systemctl status fail2ban
fail2ban-client status sshd

# Estado del firewall
ufw status verbose

# Logs de SSH
tail -f /var/log/auth.log
```

## 🆘 Rollback en caso de problemas

```bash
# Restaurar SSH original
cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
systemctl restart sshd

# Deshabilitar firewall
ufw disable
```

## 📊 Monitoreo post-instalación

```bash
# Ver intentos bloqueados por fail2ban
fail2ban-client status sshd

# Ver IPs baneadas
iptables -L -n | grep DROP

# Logs en tiempo real
tail -f /var/log/fail2ban.log
```

## ⚙️ Personalizaciones opcionales

### Cambiar puerto SSH

Edita `sshd_config` y `setup-firewall.sh`, cambia el puerto 22 por el que prefieras (ej: 2222).

### Restringir acceso solo a tu IP

En `setup-firewall.sh`, reemplaza:
```bash
ufw allow 22/tcp
```
por:
```bash
ufw allow from TU_IP_AQUI to any port 22
```

### Ajustar tiempos de baneo

Edita `jail.local`:
- `bantime`: tiempo de baneo (3600 = 1 hora)
- `findtime`: ventana de tiempo para contar intentos
- `maxretry`: intentos permitidos
