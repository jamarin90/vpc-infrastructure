# Nginx + Let's Encrypt

Configuración de Nginx como reverse proxy con certificados SSL gratuitos de Let's Encrypt.

## 📋 Requisitos previos

- ✅ Paso 1 completado (SSH + Firewall)
- ✅ Dominio apuntando al servidor (registro A en DNS)
- ✅ Puertos 80 y 443 abiertos en firewall

## 🔍 Verificar DNS antes de empezar

Desde tu máquina local, verifica que tu dominio apunta al servidor:

```bash
# Reemplaza tu-dominio.com con tu dominio real
dig tu-dominio.com +short
# Debe mostrar la IP de tu servidor

# O con nslookup
nslookup tu-dominio.com
```

**IMPORTANTE:** Let's Encrypt no funcionará si el dominio no apunta correctamente al servidor.

## 📋 Pasos de instalación

### 1. Subir archivos al servidor

```bash
# Desde tu máquina local
scp -r 02-nginx-letsencrypt/ root@tu-servidor:/root/
```

### 2. Conectarte al servidor

```bash
ssh root@tu-servidor
cd /root/02-nginx-letsencrypt
```

### 3. Ejecutar instalación

```bash
chmod +x install.sh get-ssl-cert.sh
./install.sh
```

Esto instalará:
- Nginx
- Certbot (cliente de Let's Encrypt)
- Python3 y dependencias necesarias

### 4. Obtener certificado SSL

**Opción A: Certificado para dominio específico**
```bash
# Reemplaza con tu dominio y email
./get-ssl-cert.sh tu-dominio.com tu-email@ejemplo.com
```

**Opción B: Certificado Wildcard (*.tu-dominio.com)**
```bash
# Con validación DNS manual
./get-wildcard-cert.sh tu-dominio.com tu-email@ejemplo.com

# Con Cloudflare DNS (automático)
./get-wildcard-cert.sh tu-dominio.com tu-email@ejemplo.com cloudflare

# Con DigitalOcean DNS (automático)
./get-wildcard-cert.sh tu-dominio.com tu-email@ejemplo.com digitalocean
```

Este script:
- Configura Nginx para verificación de Let's Encrypt
- Obtiene el certificado SSL
- Configura renovación automática
- Crea configuración SSL optimizada

### 5. Verificar instalación

```bash
# Ver estado de Nginx
systemctl status nginx

# Verificar que SSL funciona
curl https://tu-dominio.com

# Ver certificados instalados
certbot certificates
```

## 🔧 Configurar sitios adicionales

### Sitio estático simple

```bash
# Copiar plantilla
cp site-example.conf /etc/nginx/sites-available/mi-sitio.conf

# Editar con tu dominio
nano /etc/nginx/sites-available/mi-sitio.conf

# Habilitar sitio
ln -s /etc/nginx/sites-available/mi-sitio.conf /etc/nginx/sites-enabled/

# Probar configuración
nginx -t

# Recargar Nginx
systemctl reload nginx

# Obtener certificado para este sitio
certbot --nginx -d mi-sitio.com
```

### Reverse proxy (para aplicaciones)

Crea `/etc/nginx/sites-available/mi-app.conf`:

```nginx
server {
    listen 80;
    server_name app.tu-dominio.com;

    location / {
        proxy_pass http://localhost:3000;  # Puerto de tu aplicación
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Luego:
```bash
ln -s /etc/nginx/sites-available/mi-app.conf /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
certbot --nginx -d app.tu-dominio.com
```

## 🌟 Certificados Wildcard

Los certificados wildcard (`*.tu-dominio.com`) permiten usar un solo certificado para todos los subdominios.

### ¿Cuándo usar wildcard?

| Situación | Recomendación |
|-----------|---------------|
| 1-3 subdominios | Certificados individuales |
| 4+ subdominios | Certificado wildcard |
| Subdominios dinámicos | Certificado wildcard |
| Máxima simplicidad | Certificado wildcard |

### Requisitos para wildcard

Los certificados wildcard **requieren validación DNS** (no HTTP). Tienes dos opciones:

1. **Manual**: Crear registros TXT manualmente (no permite renovación automática)
2. **Automático**: Usar un proveedor DNS soportado (Cloudflare, DigitalOcean, Route53, etc.)

### Obtener certificado wildcard

```bash
# Opción 1: Validación manual (se te pedirá crear registros TXT)
./get-wildcard-cert.sh ejemplo.com admin@ejemplo.com

# Opción 2: Con Cloudflare (automático)
./get-wildcard-cert.sh ejemplo.com admin@ejemplo.com cloudflare

# Opción 3: Con DigitalOcean (automático)
./get-wildcard-cert.sh ejemplo.com admin@ejemplo.com digitalocean

# Opción 4: Con AWS Route53 (automático)
./get-wildcard-cert.sh ejemplo.com admin@ejemplo.com route53

# Opción 5: Con Google Cloud DNS (automático)
./get-wildcard-cert.sh ejemplo.com admin@ejemplo.com google
```

### Configurar Nginx con wildcard

Una vez obtenido el certificado, todos los subdominios usan los mismos archivos:

```nginx
# /etc/nginx/sites-available/app.ejemplo.com.conf
server {
    listen 443 ssl http2;
    server_name app.ejemplo.com;

    ssl_certificate /etc/letsencrypt/live/ejemplo.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ejemplo.com/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    location / {
        proxy_pass http://localhost:3000;
        # ... resto de configuración proxy
    }
}

# /etc/nginx/sites-available/api.ejemplo.com.conf
server {
    listen 443 ssl http2;
    server_name api.ejemplo.com;

    # Mismos certificados
    ssl_certificate /etc/letsencrypt/live/ejemplo.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ejemplo.com/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    location / {
        proxy_pass http://localhost:4000;
    }
}
```

### Proveedores DNS soportados

| Proveedor | Plugin | Configuración |
|-----------|--------|---------------|
| Cloudflare | `python3-certbot-dns-cloudflare` | API Token |
| DigitalOcean | `python3-certbot-dns-digitalocean` | API Token |
| AWS Route53 | `python3-certbot-dns-route53` | AWS credentials |
| Google Cloud | `python3-certbot-dns-google` | Service Account JSON |

### Renovación de certificados wildcard

- **Con proveedor DNS automático**: Renovación automática cada 60 días
- **Con validación manual**: Debes renovar manualmente antes de 90 días

```bash
# Verificar estado de renovación
certbot certificates

# Probar renovación (dry-run)
certbot renew --dry-run
```

## 🔄 Renovación automática

Los certificados de Let's Encrypt duran 90 días pero se renuevan automáticamente.

```bash
# Verificar que el timer está activo
systemctl status certbot.timer

# Probar renovación (dry-run, no renueva realmente)
certbot renew --dry-run

# Ver cuándo expiran los certificados
certbot certificates
```

## 🔍 Verificar seguridad SSL

Usa herramientas online para verificar tu configuración SSL:
- https://www.ssllabs.com/ssltest/
- https://securityheaders.com/

Deberías obtener calificación A o superior.

## 🆘 Troubleshooting

### Error: "Connection refused"

```bash
# Verificar que Nginx está corriendo
systemctl status nginx

# Ver logs de error
tail -f /var/log/nginx/error.log
```

### Error de Let's Encrypt: "Failed authorization"

```bash
# Verificar que el dominio apunta al servidor
dig tu-dominio.com +short

# Verificar que puertos 80 y 443 están abiertos
ufw status | grep -E '80|443'

# Ver logs de certbot
less /var/log/letsencrypt/letsencrypt.log
```

### Error: "Too many certificates already issued"

Let's Encrypt tiene límites de tasa. Si alcanzaste el límite:
- Espera 7 días
- Usa `--staging` para pruebas: `certbot --nginx --staging`

### Sitio no carga con HTTPS

```bash
# Verificar certificados
certbot certificates

# Verificar configuración SSL en Nginx
nginx -t

# Ver logs
tail -f /var/log/nginx/error.log
```

## 📊 Comandos útiles

```bash
# Ver todos los sitios habilitados
ls -la /etc/nginx/sites-enabled/

# Probar configuración sin aplicarla
nginx -t

# Recargar configuración (sin downtime)
systemctl reload nginx

# Reiniciar Nginx
systemctl restart nginx

# Ver logs en tiempo real
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Ver estadísticas de conexiones
ss -tulpn | grep nginx

# Revocar un certificado
certbot revoke --cert-name tu-dominio.com

# Eliminar un certificado
certbot delete --cert-name tu-dominio.com
```

## 🔐 Mejores prácticas

1. **Siempre usa HTTPS** - Redirige HTTP a HTTPS automáticamente
2. **Actualiza regularmente** - `apt update && apt upgrade`
3. **Monitorea logs** - Revisa regularmente los logs de acceso y error
4. **Backup** - Guarda tus configuraciones en control de versiones
5. **Rate limiting** - Configura límites para prevenir abuso
6. **Headers de seguridad** - Ya incluidos en la configuración base

## 📁 Estructura de archivos

```
/etc/nginx/
├── nginx.conf              # Configuración principal
├── sites-available/        # Configuraciones de sitios disponibles
│   ├── default
│   └── mi-sitio.conf
├── sites-enabled/          # Sitios activos (symlinks)
│   └── mi-sitio.conf -> ../sites-available/mi-sitio.conf
└── snippets/
    └── ssl-params.conf     # Parámetros SSL (creado por script)

/etc/letsencrypt/
├── live/
│   └── tu-dominio.com/
│       ├── fullchain.pem   # Certificado
│       └── privkey.pem     # Llave privada
└── renewal/                # Configuración de renovación
```

## ⚙️ Configuración avanzada

### Rate limiting

Añade a tu configuración de Nginx:

```nginx
# En http block de nginx.conf
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;

# En server block
limit_req zone=general burst=20 nodelay;
```

### Logs personalizados por sitio

```nginx
server {
    access_log /var/log/nginx/mi-sitio-access.log;
    error_log /var/log/nginx/mi-sitio-error.log;
}
```

### Gzip compression

Ya incluido en la configuración base, pero puedes ajustar:

```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript;
```
