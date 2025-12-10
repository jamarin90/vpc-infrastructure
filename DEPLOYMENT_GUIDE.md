# Guía de Deployment y Backup

Cómo guardar este proyecto de forma segura, reusable y automática.

## 🎯 Estrategia recomendada

### 1. **GitHub (público)** - Scripts y configuraciones
- ✅ Scripts de instalación
- ✅ Configuraciones base (sin secrets)
- ✅ Documentación
- ✅ Versionado y control de cambios
- ❌ NO incluir: llaves, contraseñas, IPs

### 2. **Repositorio privado** - Configuraciones específicas
- ✅ Variables de entorno
- ✅ Configuraciones personalizadas
- ✅ Backups encriptados
- ✅ Secrets y llaves

### 3. **Backup local encriptado** - Datos críticos
- ✅ Llaves SSH
- ✅ Llaves VPN (WireGuard)
- ✅ Certificados SSL
- ✅ Configuraciones con IPs

## 📋 Paso 1: Preparar para Git

Ya tienes un `.gitignore` que protege archivos sensibles. Vamos a verificarlo:

```bash
cd ~/Documents/personal/vpc

# Ver qué archivos NO se subirán
cat .gitignore

# Ver qué archivos SÍ se subirán
git status --ignored
```

**Archivos protegidos por .gitignore:**
- Llaves privadas (*.key, *.pem)
- Configuraciones de clientes VPN
- Certificados SSL
- Backups
- Variables de entorno (.env)
- IPs y datos sensibles

## 📤 Paso 2: Crear repositorio en GitHub

### Opción A: Repositorio público (Recomendado para scripts)

```bash
cd ~/Documents/personal/vpc

# Inicializar git
git init

# Agregar archivos
git add .

# Primer commit
git commit -m "Initial commit: VPC infrastructure scripts

- SSH hardening + firewall setup
- Nginx + Let's Encrypt automation
- WireGuard VPN configuration
- Monitoring (Netdata + Prometheus + Grafana)
- Complete documentation and examples"

# Crear repo en GitHub (método 1: GitHub CLI)
gh repo create vpc-infrastructure --public --source=. --remote=origin --push

# O método 2: Manual
# 1. Ve a github.com/new
# 2. Crea repo "vpc-infrastructure"
# 3. Ejecuta:
git remote add origin https://github.com/TU_USUARIO/vpc-infrastructure.git
git branch -M main
git push -u origin main
```

### Opción B: Repositorio privado (Para configuraciones personalizadas)

```bash
# Igual que arriba pero con --private
gh repo create vpc-infrastructure-private --private --source=. --remote=origin --push
```

## 🔒 Paso 3: Gestión de Secrets (configuraciones sensibles)

### Método 1: Variables de entorno con .env

Crea archivos `.env` que NO se suben a Git:

```bash
# Archivo: .env.example (SÍ se sube a Git como plantilla)
cat > .env.example <<'EOF'
# Configuración del servidor
SERVER_IP=tu.ip.publica
DOMAIN=tu-dominio.com
EMAIL=tu-email@ejemplo.com

# SSH
SSH_PORT=22

# VPN
VPN_PORT=51820
VPN_NETWORK=10.8.0.0/24

# Monitoreo
GRAFANA_PASSWORD=cambiar-esto
NETDATA_USER=admin

# Email alerts
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=tu-email@gmail.com
SMTP_PASSWORD=tu-password
ALERT_EMAIL=alertas@ejemplo.com
EOF

# Archivo: .env (NO se sube, tiene tus valores reales)
cp .env.example .env
nano .env  # Editar con tus valores reales
```

### Método 2: Ansible Vault (Encriptación)

Para guardar secrets de forma segura en Git:

```bash
# Instalar Ansible
apt install ansible

# Crear archivo encriptado
ansible-vault create secrets.yml

# Contenido:
---
server_ip: "tu.ip.real"
domain: "tu-dominio-real.com"
email: "tu-email-real@ejemplo.com"
grafana_password: "password-real"
vpn_preshared_keys:
  laptop: "llave-real-aqui"
  phone: "otra-llave-real"

# Guardar y salir (te pedirá password para encriptar)

# Editar después:
ansible-vault edit secrets.yml

# Ver contenido:
ansible-vault view secrets.yml

# Usar en scripts:
ansible-vault decrypt secrets.yml --output=/tmp/secrets.yml
source /tmp/secrets.yml
rm /tmp/secrets.yml
```

### Método 3: git-crypt (Encriptación automática en Git)

```bash
# Instalar git-crypt
apt install git-crypt

# Inicializar en el repo
cd ~/Documents/personal/vpc
git-crypt init

# Crear .gitattributes para especificar qué encriptar
cat > .gitattributes <<EOF
# Encriptar estos archivos automáticamente
secrets/** filter=git-crypt diff=git-crypt
.env filter=git-crypt diff=git-crypt
**/config.production.* filter=git-crypt diff=git-crypt
EOF

# Agregar colaboradores (su GPG key)
git-crypt add-gpg-user TU_GPG_KEY_ID

# Ahora puedes agregar archivos sensibles
mkdir secrets
echo "SERVER_IP=1.2.3.4" > secrets/production.env
git add secrets/production.env
git commit -m "Add production secrets (encrypted)"

# Al clonar en otro lugar:
git clone https://github.com/tu-usuario/vpc-infrastructure.git
cd vpc-infrastructure
git-crypt unlock  # Te pedirá tu GPG key
```

## 📦 Paso 4: Script de deployment automático

Crea un script que automatice todo el proceso:

```bash
# Archivo: deploy.sh
cat > deploy.sh <<'DEPLOY_SCRIPT'
#!/bin/bash

# Script de deployment automático para VPC
# Uso: ./deploy.sh [servidor-ip] [dominio]

set -e

# Configuración
SERVER_IP=${1:-""}
DOMAIN=${2:-""}
REPO_URL="https://github.com/TU_USUARIO/vpc-infrastructure.git"

if [ -z "$SERVER_IP" ]; then
    echo "Uso: ./deploy.sh SERVER_IP DOMAIN"
    echo "Ejemplo: ./deploy.sh 1.2.3.4 ejemplo.com"
    exit 1
fi

echo "========================================="
echo "Deployment automático de VPC"
echo "========================================="
echo ""
echo "Servidor: $SERVER_IP"
echo "Dominio: $DOMAIN"
echo ""

# 1. Subir código al servidor
echo "📤 Subiendo código al servidor..."
ssh root@$SERVER_IP "mkdir -p /root/vpc-deploy"
git archive --format=tar HEAD | ssh root@$SERVER_IP "tar -xf - -C /root/vpc-deploy"

# 2. Copiar .env con configuración
echo "⚙️  Copiando configuración..."
scp .env root@$SERVER_IP:/root/vpc-deploy/

# 3. Ejecutar instalación remota
echo "🚀 Ejecutando instalación..."
ssh root@$SERVER_IP "cd /root/vpc-deploy && bash -s" <<'REMOTE_SCRIPT'
    set -e

    # Cargar variables
    source .env

    # 1. SSH + Firewall
    cd 01-ssh-firewall
    chmod +x *.sh
    ./install.sh
    ./setup-firewall.sh
    cd ..

    # 2. Nginx + Let's Encrypt
    cd 02-nginx-letsencrypt
    chmod +x *.sh
    ./install.sh
    ./get-ssl-cert.sh $DOMAIN $EMAIL
    cd ..

    # 3. WireGuard VPN
    cd 03-wireguard-vpn
    chmod +x *.sh
    ./install.sh
    cd ..

    # 4. Monitoreo
    cd 04-monitoring
    chmod +x *.sh
    ./install-netdata.sh
    cd ..

    echo ""
    echo "✅ Deployment completado!"
    echo ""
REMOTE_SCRIPT

echo ""
echo "========================================="
echo "✅ Deployment completado"
echo "========================================="
echo ""
echo "Accesos:"
echo "  - SSH: ssh root@$SERVER_IP"
echo "  - Web: https://$DOMAIN"
echo "  - VPN: Configuraciones en /root/wireguard-clients/"
echo "  - Monitor: https://monitor.$DOMAIN"
echo ""
DEPLOY_SCRIPT

chmod +x deploy.sh
```

### Usar el script:

```bash
# Edita tu .env local con los valores reales
nano .env

# Deploy automático
./deploy.sh 1.2.3.4 tu-dominio.com
```

## 💾 Paso 5: Backup de configuraciones del servidor

### Script de backup automático:

```bash
# Archivo: backup-server.sh
cat > backup-server.sh <<'BACKUP_SCRIPT'
#!/bin/bash

# Script para hacer backup de configuraciones del servidor
# Ejecutar desde tu máquina local

SERVER_IP=${1:-""}
if [ -z "$SERVER_IP" ]; then
    echo "Uso: ./backup-server.sh SERVER_IP"
    exit 1
fi

BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Haciendo backup de configuraciones..."

# Backup de configuraciones
ssh root@$SERVER_IP "tar -czf /tmp/vpc-backup.tar.gz \
    /etc/nginx/sites-available \
    /etc/wireguard \
    /etc/fail2ban/jail.local \
    /etc/ssh/sshd_config \
    /root/wireguard-clients \
    /opt/monitoring 2>/dev/null || true"

# Descargar backup
scp root@$SERVER_IP:/tmp/vpc-backup.tar.gz "$BACKUP_DIR/"

# Limpiar servidor
ssh root@$SERVER_IP "rm /tmp/vpc-backup.tar.gz"

# Encriptar backup localmente
echo "🔒 Encriptando backup..."
gpg --symmetric --cipher-algo AES256 "$BACKUP_DIR/vpc-backup.tar.gz"
rm "$BACKUP_DIR/vpc-backup.tar.gz"

echo "✅ Backup completado: $BACKUP_DIR/vpc-backup.tar.gz.gpg"
echo ""
echo "Para restaurar:"
echo "  gpg --decrypt $BACKUP_DIR/vpc-backup.tar.gz.gpg > vpc-backup.tar.gz"
echo "  scp vpc-backup.tar.gz root@SERVER:/tmp/"
echo "  ssh root@SERVER 'tar -xzf /tmp/vpc-backup.tar.gz -C /'"
BACKUP_SCRIPT

chmod +x backup-server.sh
```

### Usar backup:

```bash
# Hacer backup
./backup-server.sh 1.2.3.4

# Listar backups
ls -lh backups/

# Restaurar backup
gpg --decrypt backups/20240101_120000/vpc-backup.tar.gz.gpg > restore.tar.gz
```

## 🔄 Paso 6: Actualización automática

### Script para actualizar servidor existente:

```bash
# Archivo: update-server.sh
cat > update-server.sh <<'UPDATE_SCRIPT'
#!/bin/bash

# Actualizar servidor con últimos cambios del repo

SERVER_IP=${1:-""}
if [ -z "$SERVER_IP" ]; then
    echo "Uso: ./update-server.sh SERVER_IP"
    exit 1
fi

echo "🔄 Actualizando servidor..."

# Pull últimos cambios
git pull origin main

# Subir al servidor
git archive --format=tar HEAD | ssh root@$SERVER_IP "tar -xf - -C /root/vpc"

echo "✅ Servidor actualizado"
echo ""
echo "Reinicia servicios si es necesario:"
echo "  ssh root@$SERVER_IP 'systemctl restart nginx'"
echo "  ssh root@$SERVER_IP 'systemctl restart wg-quick@wg0'"
UPDATE_SCRIPT

chmod +x update-server.sh
```

## 🤖 Paso 7: CI/CD con GitHub Actions (Opcional)

Para deployment automático cuando hagas push:

```bash
# Archivo: .github/workflows/deploy.yml
mkdir -p .github/workflows
cat > .github/workflows/deploy.yml <<'WORKFLOW'
name: Deploy to VPC

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup SSH
      run: |
        mkdir -p ~/.ssh
        echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
        chmod 600 ~/.ssh/id_rsa
        ssh-keyscan ${{ secrets.SERVER_IP }} >> ~/.ssh/known_hosts

    - name: Deploy to server
      run: |
        git archive --format=tar HEAD | ssh root@${{ secrets.SERVER_IP }} "tar -xf - -C /root/vpc"

    - name: Verify deployment
      run: |
        ssh root@${{ secrets.SERVER_IP }} "cd /root/vpc && ./verify-all.sh"
WORKFLOW

# Configurar secrets en GitHub:
# Settings > Secrets and variables > Actions > New repository secret
# - SSH_PRIVATE_KEY: tu llave SSH privada
# - SERVER_IP: IP de tu servidor
```

## 📊 Paso 8: Estructura final recomendada

```
vpc-infrastructure/          (Repo público en GitHub)
├── 01-ssh-firewall/
├── 02-nginx-letsencrypt/
├── 03-wireguard-vpn/
├── 04-monitoring/
├── README.md
├── .gitignore              ✅ Protege archivos sensibles
├── .env.example            ✅ Plantilla (se sube)
├── deploy.sh               ✅ Script de deployment
├── update-server.sh        ✅ Script de actualización
└── backup-server.sh        ✅ Script de backup

vpc-secrets/                (Repo privado o local)
├── .env                    🔒 Configuración real
├── secrets.yml             🔒 Secrets encriptados
├── ssh-keys/               🔒 Llaves SSH
├── vpn-configs/            🔒 Configuraciones VPN
└── backups/                🔒 Backups encriptados
    └── 20240101_120000/
        └── vpc-backup.tar.gz.gpg
```

## 🎯 Checklist de seguridad

Antes de subir a GitHub:

- [ ] Verificar .gitignore funciona: `git status`
- [ ] No hay IPs en código: `grep -r "1\.2\.3\." .`
- [ ] No hay emails reales: `grep -r "@" . | grep -v example`
- [ ] No hay contraseñas: `grep -ri "password" . | grep -v example`
- [ ] Llaves en .gitignore: `git check-ignore **/*.key`
- [ ] .env no se sube: `git check-ignore .env`

## 🚀 Workflow completo

### Primera vez (setup):

```bash
# 1. Crear estructura local
cd ~/Documents/personal/vpc
git init
git add .
git commit -m "Initial commit"

# 2. Subir a GitHub
gh repo create vpc-infrastructure --public --push

# 3. Crear .env con configuración real
cp .env.example .env
nano .env

# 4. Deploy a servidor
./deploy.sh 1.2.3.4 tu-dominio.com

# 5. Backup inicial
./backup-server.sh 1.2.3.4
```

### Después (mantenimiento):

```bash
# Hacer cambios
nano 01-ssh-firewall/install.sh

# Commit y push
git add .
git commit -m "Update firewall configuration"
git push

# Actualizar servidor
./update-server.sh 1.2.3.4

# Backup después de cambios importantes
./backup-server.sh 1.2.3.4
```

### Nuevo servidor (reutilizar):

```bash
# 1. Clonar repo
git clone https://github.com/tu-usuario/vpc-infrastructure.git
cd vpc-infrastructure

# 2. Configurar nuevo servidor
cp .env.example .env
nano .env  # Poner nueva IP, dominio, etc.

# 3. Deploy automático
./deploy.sh nueva-ip.servidor nuevo-dominio.com

# ¡Listo! En minutos tienes toda la infraestructura
```

## 💡 Mejores prácticas

1. **Nunca subir secrets**: Usa .gitignore y encriptación
2. **Versionado semántico**: `v1.0.0`, `v1.1.0`, etc.
3. **Branches**: `main` (producción), `dev` (desarrollo)
4. **Backup regular**: Automatiza con cron
5. **Documentación**: Actualiza README con cambios
6. **Testing**: Prueba en servidor de desarrollo primero
7. **Rollback plan**: Guarda backups antes de cambios

## 🆘 Recuperación de desastre

Si pierdes acceso al servidor:

```bash
# 1. Nuevo servidor
./deploy.sh nueva-ip.servidor mismo-dominio.com

# 2. Restaurar backup
gpg --decrypt backups/20240101/vpc-backup.tar.gz.gpg > restore.tar.gz
scp restore.tar.gz root@nueva-ip:/tmp/
ssh root@nueva-ip 'tar -xzf /tmp/restore.tar.gz -C /'

# 3. Reiniciar servicios
ssh root@nueva-ip 'systemctl restart nginx wg-quick@wg0 netdata'
```

## 📚 Recursos adicionales

- [GitHub - Managing secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [git-crypt](https://github.com/AGWA/git-crypt)
- [Infrastructure as Code](https://www.terraform.io/)

---

**¡Listo!** Ahora tienes una estrategia completa para mantener tu infraestructura como código, segura y reusable. 🎉
