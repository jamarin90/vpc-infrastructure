# Subir a GitHub - Guía paso a paso

## 🎯 Opción 1: Repositorio público (Recomendado)

Los scripts y configuraciones base son seguros para compartir públicamente.

### Paso 1: Instalar GitHub CLI (si no lo tienes)

```bash
# macOS
brew install gh

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Login
gh auth login
```

### Paso 2: Inicializar Git y crear repo

```bash
cd ~/Documents/personal/vpc

# Inicializar Git
git init
git add .
git commit -m "Initial commit: Complete VPC infrastructure automation

Features:
- SSH hardening and firewall configuration
- Nginx with automatic Let's Encrypt SSL
- WireGuard VPN server setup
- Multiple monitoring options (Netdata, Prometheus+Grafana)
- Automated deployment and backup scripts
- Comprehensive documentation"

# Crear repo público en GitHub y subir
gh repo create vpc-infrastructure --public --source=. --remote=origin --push
```

¡Listo! Tu repo estará en: `https://github.com/TU_USUARIO/vpc-infrastructure`

### Paso 3: Añadir descripción y topics

```bash
gh repo edit --description "🚀 Complete VPC infrastructure automation: SSH security, Nginx+SSL, WireGuard VPN, and monitoring"

gh repo edit --add-topic server-automation
gh repo edit --add-topic infrastructure-as-code
gh repo edit --add-topic wireguard
gh repo edit --add-topic nginx
gh repo edit --add-topic letsencrypt
gh repo edit --add-topic monitoring
gh repo edit --add-topic debian
gh repo edit --add-topic vps
```

## 🔒 Opción 2: Repositorio privado

Si prefieres mantenerlo privado:

```bash
gh repo create vpc-infrastructure --private --source=. --remote=origin --push
```

## 📝 Verificar antes de subir

```bash
# Ver qué se va a subir
git status

# Ver archivos ignorados (NO se subirán)
git status --ignored

# Verificar que no hay secrets
grep -r "password" . | grep -v "example" | grep -v ".git"
grep -r "@" . | grep -v "example" | grep -v ".git" | grep -v "github.com"

# Ver .gitignore
cat .gitignore
```

## 🎨 Personalizar README para GitHub

Edita el README.md para agregar badges y hacer más atractivo:

```bash
cat > badges.md <<'EOF'
# VPC Infrastructure Automation

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell](https://img.shields.io/badge/shell-bash-green.svg)
![Platform](https://img.shields.io/badge/platform-debian%20%7C%20ubuntu-orange.svg)

> 🚀 Complete infrastructure automation for VPS/VPC servers with security, SSL, VPN, and monitoring

[Features](#features) • [Quick Start](#quick-start) • [Documentation](#documentation) • [License](#license)

---
EOF

# Agregar al inicio del README
cat badges.md README.md > README.tmp && mv README.tmp README.md
rm badges.md
```

## 📸 Agregar screenshot (opcional)

Si instalaste Netdata o Grafana, toma un screenshot y súbelo:

```bash
# Crear directorio para assets
mkdir -p .github/assets

# Agregar screenshots (copia tus imágenes aquí)
# .github/assets/netdata-dashboard.png
# .github/assets/grafana-dashboard.png

# Agregar al README
echo '
## Screenshots

### Netdata Dashboard
![Netdata](.github/assets/netdata-dashboard.png)

### Grafana Dashboard
![Grafana](.github/assets/grafana-dashboard.png)
' >> README.md

git add .github/assets/*.png
git commit -m "Add dashboard screenshots"
git push
```

## 🏷️ Crear release inicial

```bash
git tag -a v1.0.0 -m "Initial release

Features:
- Complete SSH hardening and firewall setup
- Nginx with automatic Let's Encrypt SSL certificates
- WireGuard VPN server with easy client management
- Three monitoring options: Basic, Netdata, Prometheus+Grafana
- Automated deployment script
- Automated backup and restore
- Comprehensive documentation"

git push origin v1.0.0

# Crear release en GitHub
gh release create v1.0.0 --title "v1.0.0 - Initial Release" --notes "First stable release with all core features"
```

## 📋 Workflow de desarrollo

### Hacer cambios

```bash
# Crear branch para cambios
git checkout -b feature/nueva-funcionalidad

# Hacer cambios
nano 01-ssh-firewall/install.sh

# Commit
git add .
git commit -m "Update firewall configuration for better security"

# Push
git push origin feature/nueva-funcionalidad

# Crear Pull Request
gh pr create --title "Improve firewall security" --body "Adds additional iptables rules for enhanced protection"
```

### Mantener actualizado

```bash
# Pull cambios remotos
git pull origin main

# Ver cambios
git log --oneline --graph

# Ver diferencias
git diff HEAD~1
```

## 🌟 Hacer el repo más visible

### 1. README atractivo

- ✅ Badges al inicio
- ✅ GIF o screenshot del dashboard
- ✅ Quick start claro
- ✅ Tabla de contenidos
- ✅ Casos de uso
- ✅ FAQ

### 2. GitHub features

```bash
# Habilitar wiki
gh repo edit --enable-wiki

# Habilitar discussions
gh repo edit --enable-discussions

# Habilitar issues
gh repo edit --enable-issues
```

### 3. Social preview

Ve a: `Settings > General > Social preview`
Y sube una imagen 1280x640px con el logo/nombre del proyecto

### 4. About section

```bash
gh repo edit --description "🚀 Complete VPC infrastructure automation with security, SSL, VPN & monitoring"
gh repo edit --homepage "https://tu-usuario.github.io/vpc-infrastructure"
```

## 📊 Clonar en otro lugar

Para usar en otro servidor:

```bash
# Clonar
git clone https://github.com/TU_USUARIO/vpc-infrastructure.git
cd vpc-infrastructure

# Configurar
cp .env.example .env
nano .env  # Editar con tus valores

# Deploy
./deploy.sh TU_IP TU_DOMINIO
```

## 🔄 Mantener sincronizado

Si haces cambios en el servidor, puedes traerlos de vuelta:

```bash
# En tu servidor
cd /root/vpc
git init
git add .
git commit -m "Production configurations"

# En tu máquina local
git remote add production root@TU_IP:/root/vpc
git pull production main --allow-unrelated-histories
```

## 📝 Licencia

Añade una licencia (MIT es recomendada para proyectos open source):

```bash
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2024 [Tu Nombre]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

git add LICENSE
git commit -m "Add MIT license"
git push
```

## ✅ Checklist final

Antes de hacer público:

- [ ] README.md completo y claro
- [ ] LICENSE añadida
- [ ] .gitignore protege archivos sensibles
- [ ] Sin passwords/secrets en el código
- [ ] Scripts son ejecutables
- [ ] Documentación de cada módulo completa
- [ ] DEPLOYMENT_GUIDE.md con instrucciones
- [ ] Badges y descripción atractivos

## 🎉 ¡Listo!

Tu proyecto está ahora en GitHub, listo para compartir o usar en múltiples servidores.

**URL de tu repo:** `https://github.com/TU_USUARIO/vpc-infrastructure`

Compártelo en:
- Twitter/X con hashtags #DevOps #SelfHosting #VPS
- Reddit en r/selfhosted, r/homelab
- Dev.to con un artículo
- Hacker News
