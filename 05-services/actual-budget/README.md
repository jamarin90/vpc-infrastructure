# Actual Budget - Finanzas Personales

App de presupuesto y finanzas personales self-hosted, basada en la metodología YNAB.

## Características

- **Ligero**: ~50-100 MB RAM
- **Offline-first**: Funciona sin conexión, sincroniza cuando hay internet
- **PWA**: Se instala como app en móvil
- **Open Source**: MIT License
- **Privado**: Tus datos en tu servidor

## Requisitos

- Docker y Docker Compose instalados
- Nginx configurado (módulo 02)
- Certificado SSL (Let's Encrypt)
- Dominio/subdominio configurado

## Instalación Rápida

```bash
# Opción 1: Con script automático
./install.sh finanzas.tudominio.com tu@email.com

# Opción 2: Manual
docker compose up -d
```

## Instalación Manual

### 1. Iniciar el contenedor

```bash
cd /root/vpc/05-services/actual-budget
docker compose up -d
```

### 2. Configurar Nginx

```bash
# Copiar configuración
sudo cp nginx-actual.conf /etc/nginx/sites-available/actual-budget

# Editar dominio
sudo nano /etc/nginx/sites-available/actual-budget
# Reemplazar: finanzas.TU_DOMINIO.com por tu dominio real
# Reemplazar: TU_DOMINIO.com por tu dominio base

# Habilitar sitio
sudo ln -s /etc/nginx/sites-available/actual-budget /etc/nginx/sites-enabled/

# Verificar y recargar
sudo nginx -t && sudo systemctl reload nginx
```

### 3. Obtener certificado SSL

```bash
# Si usas subdominio nuevo
sudo certbot --nginx -d finanzas.tudominio.com

# Si ya tienes wildcard (*.tudominio.com), no necesitas esto
```

## Primer Uso

1. Abre `https://finanzas.tudominio.com`
2. Crea una contraseña de servidor (protege el acceso)
3. Crea tu primer archivo de presupuesto
4. Configura tus cuentas y categorías

## Instalar como App Móvil (PWA)

### iPhone/iPad
1. Abre Safari
2. Ve a tu URL de Actual Budget
3. Toca el botón "Compartir"
4. Selecciona "Añadir a pantalla de inicio"

### Android
1. Abre Chrome
2. Ve a tu URL de Actual Budget
3. Toca el menú (3 puntos)
4. Selecciona "Instalar aplicación"

## Crear APK (Opcional)

Si quieres un APK instalable:

1. Ve a [PWA Builder](https://pwabuilder.com)
2. Ingresa tu URL: `https://finanzas.tudominio.com`
3. Descarga el APK generado

## Estructura de Archivos

```
actual-budget/
├── docker-compose.yml    # Configuración del contenedor
├── nginx-actual.conf     # Configuración de Nginx
├── install.sh            # Script de instalación
├── README.md             # Esta documentación
└── data/                 # Datos persistentes (creado automáticamente)
    └── *.sqlite          # Base de datos de presupuestos
```

## Comandos Útiles

```bash
# Ver estado
docker ps | grep actual

# Ver logs
docker logs -f actual-budget

# Reiniciar
docker restart actual-budget

# Detener
docker stop actual-budget

# Iniciar
docker start actual-budget

# Actualizar a última versión
docker compose pull
docker compose up -d

# Backup de datos
tar -czvf actual-backup-$(date +%Y%m%d).tar.gz data/
```

## Backup y Restauración

### Backup
```bash
# Desde el servidor
cd /root/vpc/05-services/actual-budget
tar -czvf ~/actual-backup-$(date +%Y%m%d).tar.gz data/
```

### Restauración
```bash
# Detener servicio
docker stop actual-budget

# Restaurar datos
tar -xzvf actual-backup-YYYYMMDD.tar.gz

# Iniciar servicio
docker start actual-budget
```

## Recursos

| RAM | CPU | Disco |
|-----|-----|-------|
| ~50-100 MB | Mínimo | ~50 MB + datos |

## Sincronización entre dispositivos

Actual Budget sincroniza automáticamente entre todos tus dispositivos:

1. Primer dispositivo: Crea el presupuesto
2. Otros dispositivos: Abre la misma URL y selecciona el presupuesto existente

Los cambios se sincronizan en tiempo real cuando hay conexión.

## Troubleshooting

### No carga la página
```bash
# Verificar contenedor
docker ps | grep actual

# Ver logs
docker logs actual-budget

# Verificar Nginx
sudo nginx -t
sudo systemctl status nginx
```

### Error de certificado SSL
```bash
# Renovar certificado
sudo certbot renew

# O obtener nuevo
sudo certbot --nginx -d finanzas.tudominio.com
```

### Error de sincronización
- Verifica que el límite de subida en Nginx sea suficiente (50M configurado)
- Revisa los logs: `docker logs actual-budget`

## Enlaces

- [Documentación oficial](https://actualbudget.org/docs/)
- [GitHub](https://github.com/actualbudget/actual)
- [Comunidad Discord](https://discord.gg/pRYNYr4W5A)
