# ttyd - Terminal Web

Terminal SSH accesible desde el navegador. Ligero y simple.

## Instalacion Rapida

### 1. En el servidor

```bash
cd /opt
sudo mkdir -p ttyd
cd ttyd
```

### 2. Sube los archivos

- `docker-compose.yml`
- `ttyd.nginx.conf`

### 3. Cambia las credenciales

```bash
nano docker-compose.yml
# Cambia: admin y cambiame123 por tus credenciales
```

### 4. Inicia el contenedor

```bash
docker-compose up -d
```

### 5. Configura SSL y Nginx

```bash
# Obtener certificado
sudo /root/vpc/02-nginx-letsencrypt/get-ssl-cert.sh term.tudominio.com tu@email.com

# Copiar y editar config nginx
sudo cp ttyd.nginx.conf /etc/nginx/sites-available/ttyd.conf
sudo nano /etc/nginx/sites-available/ttyd.conf
# Reemplaza "term.tudominio.com" por tu dominio

# Habilitar
sudo ln -s /etc/nginx/sites-available/ttyd.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 6. Accede

Abre `https://term.tudominio.com`

Te pedira usuario/password (los que configuraste en docker-compose.yml)

## Seguridad Recomendada

### Opcion 1: Restringir por IP (recomendado)

Edita `/etc/nginx/sites-available/ttyd.conf`:

```nginx
# Dentro del bloque server { ... }
allow 10.0.0.0/24;    # Tu red WireGuard
deny all;
```

Asi solo puedes acceder cuando estas conectado a tu VPN.

### Opcion 2: Autenticacion adicional con Authelia

Si tienes Authelia configurado, agrega:

```nginx
location / {
    auth_request /authelia;
    # ... resto de config
}
```

## Comandos Utiles

```bash
# Ver logs
docker-compose logs -f ttyd

# Reiniciar
docker-compose restart

# Cambiar credenciales
nano docker-compose.yml
docker-compose up -d

# Parar
docker-compose down
```

## Montar carpetas del host

Si quieres acceder a carpetas del servidor desde ttyd, edita `docker-compose.yml`:

```yaml
volumes:
  - /home/tu-usuario:/root/home:rw
  - /var/log:/root/logs:ro
  - /etc:/root/etc:ro
```

## Diferencias con Wetty

| ttyd | Wetty |
|------|-------|
| ~5MB imagen | ~200MB imagen |
| C (rapido) | Node.js |
| Auth basica | Auth basica + PAM |
| Mas simple | Mas features |

## Recursos

- Imagen Docker: ~5MB
- RAM: ~10-20MB
- CPU: Minimo
