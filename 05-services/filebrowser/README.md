# FileBrowser

Gestor de archivos web simple y ligero.

## Instalacion Rapida

### 1. En el servidor, crea la estructura

```bash
cd /opt
sudo mkdir -p filebrowser/data
cd filebrowser
```

### 2. Copia los archivos

Sube estos archivos al servidor:
- `docker-compose.yml`
- `settings.json`

### 3. Crea la base de datos vacia

```bash
touch filebrowser.db
```

### 4. Inicia el contenedor

```bash
docker-compose up -d
```

### 5. Configura Nginx + SSL

```bash
# Obtener certificado SSL
sudo /root/vpc/02-nginx-letsencrypt/get-ssl-cert.sh files.tudominio.com tu@email.com

# Copiar configuracion nginx
sudo cp filebrowser.nginx.conf /etc/nginx/sites-available/filebrowser.conf

# Editar dominio en el archivo
sudo nano /etc/nginx/sites-available/filebrowser.conf

# Habilitar sitio
sudo ln -s /etc/nginx/sites-available/filebrowser.conf /etc/nginx/sites-enabled/

# Verificar y recargar
sudo nginx -t && sudo systemctl reload nginx
```

### 6. Accede

Abre `https://files.tudominio.com`

**Credenciales por defecto:**
- Usuario: `admin`
- Password: `admin`

**IMPORTANTE:** Cambia la contraseña inmediatamente en Settings > User Management

## Estructura de Archivos

```
/opt/filebrowser/
├── docker-compose.yml    # Configuracion Docker
├── settings.json         # Config de FileBrowser
├── filebrowser.db        # Base de datos (usuarios, config)
└── data/                 # Tus archivos van aqui
```

## Comandos Utiles

```bash
# Ver logs
docker-compose logs -f filebrowser

# Reiniciar
docker-compose restart

# Parar
docker-compose down

# Actualizar a ultima version
docker-compose pull && docker-compose up -d
```

## Configuracion Adicional

### Cambiar limite de subida

Edita `filebrowser.nginx.conf`:
```nginx
client_max_body_size 10G;  # Cambia a lo que necesites
```

### Crear usuarios adicionales

1. Entra a FileBrowser como admin
2. Settings > User Management > New
3. Asigna permisos y carpeta base

## Seguridad

- Usa HTTPS siempre (ya configurado con Let's Encrypt)
- Cambia la contraseña de admin
- Considera limitar acceso por IP si es solo para ti
- El servicio solo es accesible via Nginx (puerto 8085 no expuesto publicamente)

## Recursos

- Imagen Docker: ~50MB
- RAM: ~50MB en uso
- CPU: Minimo
