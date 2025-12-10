# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains shell scripts for setting up Nginx as a reverse proxy with Let's Encrypt SSL certificates on Debian/Ubuntu servers. It's part of a VPC infrastructure automation series (step 02).

## Prerequisites

- SSH access to a Debian/Ubuntu server with root privileges
- Domain pointing to server (DNS A record)
- Ports 80 and 443 open in firewall

## Commands

### Installation and Setup (run on server)

```bash
# Install Nginx + Certbot
./install.sh

# Get SSL certificate for single domain
./get-ssl-cert.sh <domain> <email>

# Get wildcard certificate (*.domain.com)
./get-wildcard-cert.sh <domain> <email> [dns-provider]
# dns-provider options: manual, cloudflare, digitalocean, route53, google

# Verify installation status
./verify.sh
```

### Nginx Management

```bash
nginx -t                      # Test configuration
systemctl reload nginx        # Apply changes (no downtime)
systemctl restart nginx       # Full restart
certbot certificates          # List installed certificates
certbot renew --dry-run       # Test certificate renewal
```

## Architecture

```
Scripts:
├── install.sh           # Installs nginx, certbot, enables services
├── get-ssl-cert.sh      # Single domain cert via HTTP-01 challenge
├── get-wildcard-cert.sh # Wildcard cert via DNS-01 challenge
└── verify.sh            # Checks nginx, certbot, certs status

Server paths (after installation):
├── /etc/nginx/sites-available/  # Site configurations
├── /etc/nginx/sites-enabled/    # Active sites (symlinks)
├── /etc/nginx/snippets/ssl-params.conf  # SSL hardening config
├── /etc/letsencrypt/live/<domain>/      # Certificate files
└── /var/www/<domain>/           # Web root directories
```

## Key Implementation Details

- `get-ssl-cert.sh` uses Certbot's nginx plugin with HTTP-01 challenge (automatic)
- `get-wildcard-cert.sh` requires DNS-01 challenge (manual TXT records or DNS provider API)
- Scripts create optimized SSL params including TLS 1.2/1.3, HSTS, security headers
- Diffie-Hellman parameters (2048-bit) generated on first SSL cert request
- Certbot timer handles automatic certificate renewal

## DNS Provider Credentials

For automated wildcard renewal, credentials stored in:
- Cloudflare: `/etc/letsencrypt/cloudflare.ini`
- DigitalOcean: `/etc/letsencrypt/digitalocean.ini`
- Google Cloud: `/etc/letsencrypt/google.json`
