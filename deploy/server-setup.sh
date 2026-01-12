#!/bin/bash

# ========================================
# MyTelUV2 VPS Server Setup Script
# For Ubuntu 22.04 LTS or newer
# ========================================

set -e

echo "========================================="
echo "MyTelUV2 Server Setup"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# Update system
echo -e "${BLUE}Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

# Install essential packages
echo -e "${BLUE}Installing essential packages...${NC}"
apt-get install -y \
    curl \
    wget \
    git \
    ufw \
    fail2ban

# Install Docker
echo -e "${BLUE}Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${YELLOW}Docker already installed${NC}"
fi

# Install Docker Compose (v2)
echo -e "${BLUE}Installing Docker Compose...${NC}"
if ! docker compose version &> /dev/null; then
    apt-get install -y docker-compose-plugin
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
else
    echo -e "${YELLOW}Docker Compose already installed${NC}"
fi

# Add current user to docker group
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" != "root" ]; then
    usermod -aG docker "$CURRENT_USER"
    echo -e "${GREEN}✓ Added $CURRENT_USER to docker group${NC}"
fi

# Configure firewall
echo -e "${BLUE}Configuring firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw --force enable
echo -e "${GREEN}✓ Firewall configured${NC}"

# Configure fail2ban
echo -e "${BLUE}Configuring fail2ban...${NC}"
systemctl enable fail2ban
systemctl start fail2ban
echo -e "${GREEN}✓ fail2ban configured${NC}"

# Create application directory
APP_DIR="/opt/myteluv2"
echo -e "${BLUE}Creating application directory at $APP_DIR...${NC}"
mkdir -p "$APP_DIR"
chown "$CURRENT_USER":"$CURRENT_USER" "$APP_DIR"

# Done
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✨ Server Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "📝 Next Steps:"
echo ""
echo -e "${YELLOW}1. Clone your repository:${NC}"
echo "   cd /opt/myteluv2"
echo "   git clone https://github.com/YOUR_USERNAME/MyTelUV2.git ."
echo ""
echo -e "${YELLOW}2. Create .env file:${NC}"
echo "   cp .env.example .env"
echo "   nano .env  # Edit with your values"
echo ""
echo -e "${YELLOW}3. Start the application:${NC}"
echo "   docker compose -f docker-compose.prod.yml up -d --build"
echo ""
echo -e "${YELLOW}4. View logs:${NC}"
echo "   docker compose -f docker-compose.prod.yml logs -f"
echo ""
echo -e "${BLUE}💡 Useful commands:${NC}"
echo "   docker compose ps              # List running containers"
echo "   docker compose logs -f         # View logs"
echo "   docker compose down            # Stop all containers"
echo "   docker compose up -d --build   # Rebuild and restart"
echo ""

# Logout reminder
if [ "$CURRENT_USER" != "root" ]; then
    echo -e "${YELLOW}⚠️  IMPORTANT: Log out and log back in for docker group to take effect${NC}"
fi
