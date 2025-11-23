#!/bin/bash
# g̶o̶o̶d̶ f̶o̶r̶ h̶e̶a̶l̶t̶h̶,̶ b̶a̶d̶ f̶o̶r̶ e̶d̶u̶c̶a̶t̶i̶o̶n̶

# Script de instalación para CasaOS y aplicaciones adicionales
# Requiere ejecución como root

if [ "$EUID" -ne 0 ]; then
    echo "Por favor, ejecuta este script como root o usando sudo."
    exit 1
fi

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Actualizar sistema
print_message "Actualizando el sistema..."
apt update && apt upgrade -y

# Instalar dependencias básicas
print_message "Instalando dependencias básicas..."
apt install -y \
    curl \
    wget \
    git \
    unzip \
    btop \
    nano \
    ufw \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Instalar Docker
print_message "Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Instalar Docker Compose
print_message "Instalando Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Instalar CasaOS
print_message "Instalando CasaOS..."
curl -fsSL https://get.casaos.io | bash

# Instalar aplicaciones adicionales
print_message "Instalando aplicaciones adicionales..."

# instalar oh my zsh
print_message "instalando zsh con esteroides"
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"


# Instalar Portainer (gestión de Docker)
docker volume create portainer_data
docker run -d \
    --name portainer \
    --restart always \
    -p 8000:8000 \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

# Instalar Nginx Proxy Manager
docker run -d \
    --name nginx-proxy-manager \
    --restart always \
    -p 80:80 \
    -p 81:81 \
    -p 443:443 \
    -v /docker/nginx-proxy-manager/data:/data \
    -v /docker/nginx-proxy-manager/letsencrypt:/etc/letsencrypt \
    jc21/nginx-proxy-manager:latest

# Configurar firewall
print_message "Configurando firewall..."
ufw allow ssh
ufw allow http
ufw allow https
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8000/tcp
ufw allow 9443/tcp
ufw --force enable

# Instalar herramientas de monitorización
print_message "Instalando herramientas de monitorización..."
apt install -y \
    iotop \
    nethogs \
    nmon \
    btop

# Instalar Netdata (monitorización en tiempo real)
bash <(curl -Ss https://my-netdata.io/kickstart.sh) --non-interactive

# Instalar servicios adicionales via Docker Compose
print_message "Configurando servicios adicionales..."

# Crear directorio para servicios
mkdir -p /docker/services
cd /docker/services

# Archivo Docker Compose para servicios adicionales
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - /srv:/srv
      - /docker/filebrowser:/config
    environment:
      - TZ=America/Mexico_City

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 3600 --cleanup
    environment:
      - TZ=America/Mexico_City

  heimdall:
    image: lscr.io/linuxserver/heimdall:latest
    container_name: heimdall
    restart: unless-stopped
    ports:
      - "8081:80"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Mexico_City
    volumes:
      - /docker/heimdall:/config

  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - /docker/uptime-kuma:/app/data
EOF

# Iniciar servicios adicionales
print_message "Iniciando servicios adicionales..."
docker-compose up -d

# Instalar script de mantenimiento
print_message "Configurando scripts de mantenimiento..."

cat > /usr/local/bin/limpiar-sistema.sh << 'EOF'
#!/bin/bash
echo "Limpiando sistema..."
docker system prune -f
docker volume prune -f
apt autoremove -y
apt autoclean -y
echo "Limpieza completada"
EOF

chmod +x /usr/local/bin/limpiar-sistema.sh

# Configurar actualizaciones automáticas
print_message "Configurando actualizaciones automáticas..."
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Información final
print_message "Instalación completada!"
echo "=================================================="
echo "Accesos principales:"
echo "- CasaOS: http://$(hostname -I | awk '{print $1}'):80"
echo "- Portainer: https://$(hostname -I | awk '{print $1}'):9443"
echo "- Nginx Proxy Manager: http://$(hostname -I | awk '{print $1}'):81"
echo "- Netdata: http://$(hostname -I | awk '{print $1}'):19999"
echo "- FileBrowser: http://$(hostname -I | awk '{print $1}'):8080"
echo "- Heimdall: http://$(hostname -I | awk '{print $1}'):8081"
echo "- Uptime Kuma: http://$(hostname -I | awk '{print $1}'):3001"
echo "=================================================="
print_warning "Por favor, cambia las contraseñas por defecto!"
print_warning "Revisa la configuración de firewall: ufw status"
print_message "Puedes usar 'limpiar-sistema.sh' para mantenimiento"

# Reiniciar servicios
print_message "Reiniciando servicios..."
systemctl restart docker
docker restart casaos

print_message "¡Instalación finalizada completamente!"