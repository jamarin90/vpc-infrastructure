# Guía de inicio rápido - 30 minutos

Esta guía te llevará de un servidor vacío a un sistema completo con seguridad, SSL y VPN en ~30 minutos.

## 📋 Pre-requisitos

- [x] Servidor Debian en Contabo (o similar)
- [x] Acceso SSH con root
- [x] Dominio apuntando al servidor
- [x] 30 minutos de tiempo

## 🚀 Paso a paso

### 0. Preparación (2 min)

```bash
# En tu máquina local, clonar o descargar este repositorio
cd ~/Downloads
# Asume que tienes estos archivos aquí

# Subir al servidor
scp -r vpc root@TU_IP_SERVIDOR:~/

# Conectar al servidor
ssh root@TU_IP_SERVIDOR
cd ~/vpc
```

### 1. Seguridad SSH + Firewall (10 min)

```bash
cd 01-ssh-firewall

# Instalar fail2ban y ufw
chmod +x *.sh
./install.sh

# Configurar firewall
./setup-firewall.sh

# Aplicar configuración SSH
# ⚠️ IMPORTANTE: Mantén la sesión abierta
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
cp sshd_config /etc/ssh/sshd_config
sshd -t  # Verificar que no hay errores

# Si todo OK, reiniciar SSH
systemctl restart sshd

# En OTRA terminal, probar que puedes conectar
ssh root@TU_IP_SERVIDOR

# Si funciona, ¡perfecto! Continúa
# Si no funciona, usa la sesión original y ejecuta:
# ./rollback.sh

# Verificar
./verify.sh
```

**✅ Checkpoint:** fail2ban corriendo, firewall activo, SSH con llaves

### 2. Nginx + Let's Encrypt (10 min)

```bash
cd ../02-nginx-letsencrypt

# Verificar que tu dominio apunta al servidor
dig TU_DOMINIO.com +short
# Debe mostrar tu IP del servidor

# Instalar Nginx + Certbot
chmod +x *.sh
./install.sh

# Obtener certificado SSL
./get-ssl-cert.sh TU_DOMINIO.com TU_EMAIL@ejemplo.com

# El script:
# - Crea configuración básica
# - Obtiene certificado SSL
# - Configura renovación automática
# - Muestra página de prueba

# Verificar
./verify.sh

# Probar en navegador
# https://TU_DOMINIO.com
```

**✅ Checkpoint:** Nginx corriendo, SSL activo, dominio accesible por HTTPS

### 3. WireGuard VPN (10 min)

```bash
cd ../03-wireguard-vpn

# Instalar WireGuard
chmod +x *.sh
./install.sh

# Agregar tu laptop como cliente
./add-client.sh laptop

# El script muestra:
# 1. Código QR (para móvil)
# 2. Ruta al archivo .conf (para desktop)

# Para desktop: Descargar configuración
# En tu máquina local (nueva terminal):
scp root@TU_IP_SERVIDOR:~/wireguard-clients/laptop.conf ~/

# Conectar (en tu máquina local):
# Linux/Mac:
sudo cp ~/laptop.conf /etc/wireguard/
sudo wg-quick up laptop

# Windows:
# - Descargar WireGuard GUI
# - Importar laptop.conf
# - Activar

# Verificar (en el servidor)
./verify.sh
wg show  # Debes aparecer conectado

# Verificar (en tu laptop, conectado a VPN)
curl ifconfig.me  # Debe mostrar IP del servidor
ping 10.8.0.1     # Ping al servidor VPN
```

**✅ Checkpoint:** VPN funcionando, puedes conectarte desde tu laptop

## 🎉 ¡Listo!

En ~30 minutos has configurado:
- ✅ Servidor seguro con firewall y fail2ban
- ✅ Nginx con SSL gratuito de Let's Encrypt
- ✅ VPN personal con WireGuard

## 🔍 Verificación completa

```bash
# En el servidor
cd ~/vpc

# Verificar cada componente
cd 01-ssh-firewall && ./verify.sh && cd ..
cd 02-nginx-letsencrypt && ./verify.sh && cd ..
cd 03-wireguard-vpn && ./verify.sh && cd ..
```

Todo debe mostrar checkmarks verdes ✅

## 📝 Próximos pasos comunes

### A. Agregar más clientes VPN

```bash
cd ~/vpc/03-wireguard-vpn

# Tu teléfono
./add-client.sh phone
# Escanea el QR con la app de WireGuard

# Tablet
./add-client.sh tablet
```

### B. Agregar más dominios con SSL

```bash
cd ~/vpc/02-nginx-letsencrypt

# Subdominio para blog
./get-ssl-cert.sh blog.TU_DOMINIO.com TU_EMAIL@ejemplo.com

# Subdominio para app
./get-ssl-cert.sh app.TU_DOMINIO.com TU_EMAIL@ejemplo.com
```

### C. Montar tu primera app en Docker

```bash
# Ejemplo: App Node.js
docker run -d \
  --name mi-app \
  --restart unless-stopped \
  -p 3000:3000 \
  mi-imagen:latest

# Configurar Nginx reverse proxy
cat > /etc/nginx/sites-available/app.conf <<EOF
server {
    listen 80;
    server_name app.TU_DOMINIO.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Habilitar sitio
ln -s /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx

# Obtener SSL
certbot --nginx -d app.TU_DOMINIO.com

# ¡Listo! https://app.TU_DOMINIO.com
```

## 🆘 Problemas comunes

### "No puedo conectar por SSH"

**Solución:** Usa la consola web de Contabo, ejecuta:
```bash
cd ~/vpc/01-ssh-firewall
./rollback.sh
```

### "SSL no funciona"

**Solución:** Verificar DNS
```bash
dig TU_DOMINIO.com +short
# Debe mostrar la IP del servidor

# Ver logs
tail -f /var/log/letsencrypt/letsencrypt.log
```

### "VPN conecta pero no hay internet"

**Solución:**
```bash
# Verificar IP forwarding
sysctl net.ipv4.ip_forward  # Debe ser 1

# Reiniciar WireGuard
systemctl restart wg-quick@wg0
```

## 📚 Documentación completa

Para más detalles, consulta:
- [README.md](README.md) - Guía principal completa
- [01-ssh-firewall/README.md](01-ssh-firewall/README.md)
- [02-nginx-letsencrypt/README.md](02-nginx-letsencrypt/README.md)
- [03-wireguard-vpn/README.md](03-wireguard-vpn/README.md)

## 🎯 Checklist final

Marca cada item cuando lo completes:

- [ ] SSH configurado con llaves (no passwords)
- [ ] fail2ban instalado y corriendo
- [ ] Firewall (ufw) activo
- [ ] Nginx instalado y corriendo
- [ ] Certificado SSL obtenido y funcionando
- [ ] Renovación automática de SSL configurada
- [ ] WireGuard instalado y corriendo
- [ ] Al menos un cliente VPN configurado
- [ ] Puedes conectarte a la VPN desde tu dispositivo
- [ ] Backup de configuraciones descargado a tu máquina local

## 💾 Backup (IMPORTANTE)

```bash
# En el servidor
tar -czf vpc-backup-$(date +%Y%m%d).tar.gz \
    /etc/nginx/sites-available \
    /etc/wireguard \
    /etc/fail2ban/jail.local \
    /etc/ssh/sshd_config \
    ~/wireguard-clients

# En tu máquina local
scp root@TU_IP_SERVIDOR:~/vpc-backup-*.tar.gz ~/backups/
```

**Guarda este backup en un lugar seguro!**

---

## 🎊 ¡Felicidades!

Tu servidor está listo y seguro. Ahora puedes:
- Hospedar aplicaciones web con SSL
- Navegar seguro desde cualquier lugar con tu VPN
- Acceder a servicios privados vía VPN
- Montar tus proyectos en Docker

**¡Disfruta tu infraestructura personal!** 🚀
