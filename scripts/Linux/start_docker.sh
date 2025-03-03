#!/bin/bash
# Printer SNMP Management - Docker Environment Startup Script

echo "========================================================="
echo "Printer SNMP Management - Starting Docker Environment"
echo "========================================================="

# Get script directory
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker and Docker Compose first."
    echo "Visit https://docs.docker.com/get-docker/ for installation instructions."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose &> /dev/null; then
    echo "Docker Compose is not installed or not available. Please install Docker Compose."
    echo "Visit https://docs.docker.com/compose/install/ for installation instructions."
    exit 1
fi

# Build frontend for production
echo "Building frontend for production..."
cd "../FrontEnd"
npm run build
if [ $? -ne 0 ]; then
    echo "Failed to build frontend. Exiting."
    exit 1
fi
cd "$SCRIPT_DIR"

# Check compose file location
if [ -f "../Server/compose.yml" ]; then
    COMPOSE_FILE="../Server/compose.yml"
elif [ -f "../Server/docker-compose.yml" ]; then
    COMPOSE_FILE="../Server/docker-compose.yml"
else
    echo "Docker Compose file not found. Creating a default compose file..."
    
    # Create a compose file if it doesn't exist
    cat > "../Server/compose.yml" << EOL
version: '3.8'

services:
  server:
    build:
      context: .
      dockerfile: dockerfile
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - NODE_OPTIONS=--max-old-space-size=2048
    volumes:
      - ./data:/app/data
    networks:
      - printer-snmp-network
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 1G
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s

  frontend:
    build:
      context: ../FrontEnd
      dockerfile: dockerfile.frontend
    restart: unless-stopped
    ports:
      - "80:80"
    depends_on:
      - server
    networks:
      - printer-snmp-network
    deploy:
      resources:
        limits:
          cpus: '0.3'
          memory: 512M
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:80"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

networks:
  printer-snmp-network:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.28.0.0/16
EOL
    COMPOSE_FILE="../Server/compose.yml"
    
    # Check if Dockerfiles exist, create if needed
    if [ ! -f "../Server/dockerfile" ]; then
        echo "Creating server Dockerfile..."
        cat > "../Server/dockerfile" << EOL
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source files
COPY . .

# Use multi-stage build for smaller image size
FROM node:18-alpine

# Set NODE_ENV
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=1024 --optimize-for-size"

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app

# Copy only necessary files from builder stage
COPY --from=builder --chown=appuser:appgroup /app/node_modules /app/node_modules
COPY --from=builder --chown=appuser:appgroup /app/package.json /app/
COPY --from=builder --chown=appuser:appgroup /app/server.js /app/
COPY --from=builder --chown=appuser:appgroup /app/middleware /app/middleware
COPY --from=builder --chown=appuser:appgroup /app/models /app/models
COPY --from=builder --chown=appuser:appgroup /app/routes /app/routes

# Create data directory with appropriate permissions
RUN mkdir -p /app/data && chown -R appuser:appgroup /app/data

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget --spider -q http://localhost:3000/api/health || exit 1

EXPOSE 3000

CMD ["node", "--optimize-for-size", "server.js"]
EOL
    fi
    
    if [ ! -f "../FrontEnd/dockerfile.frontend" ]; then
        echo "Creating frontend Dockerfile..."
        cat > "../FrontEnd/dockerfile.frontend" << EOL
FROM node:18-alpine as build

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --production=false

# Copy source files and build
COPY . .
# Enable build optimizations
ENV GENERATE_SOURCEMAP=false
RUN npm run build

# Use Nginx Alpine for production
FROM nginx:alpine

# Copy build files and configuration
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Add security headers
RUN sed -i '1iserver_tokens off;' /etc/nginx/nginx.conf && \
    mkdir -p /var/cache/nginx && \
    chown -R nginx:nginx /var/cache/nginx

# Create non-root user and set permissions
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --spider -q http://localhost:80 || exit 1

EXPOSE 80

# Use unprivileged port and run as non-root
USER nginx

CMD ["nginx", "-g", "daemon off;"]
EOL
    fi
    
    # Check if nginx conf exists
    if [ ! -f "../FrontEnd/nginx.conf" ]; then
        echo "Creating nginx configuration..."
        cat > "../FrontEnd/nginx.conf" << EOL
# Add rate limiting zone
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

server {
    listen 80;
    server_name localhost;

    # Security headers
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Frame-Options "SAMEORIGIN";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; font-src 'self'; connect-src 'self' http://server:3000;";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

    # Enable compression
    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_types
        application/javascript
        application/json
        application/x-javascript
        application/xml
        image/svg+xml
        text/css
        text/javascript
        text/plain
        text/xml;

    # Static files with cache
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|otf|eot)$ {
        root /usr/share/nginx/html;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000";
        access_log off;
    }

    # Main application
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
        
        # No cache for HTML files
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }

    # API proxy with rate limiting
    location /api {
        proxy_pass http://server:3000/api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Security
        proxy_buffering on;
        proxy_buffer_size 8k;
        proxy_buffers 8 8k;
        
        # Rate limiting
        limit_req zone=api burst=10 nodelay;
        limit_req_status 429;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    }
EOL
    fi
fi

# Start Docker Compose
echo "Starting Docker containers..."
cd "$(dirname "$COMPOSE_FILE")"

# Check which Docker Compose command to use
if command -v docker-compose &> /dev/null; then
    # Using older docker-compose
    docker-compose -f "$(basename "$COMPOSE_FILE")" up -d --build
else
    # Using newer docker compose
    docker compose -f "$(basename "$COMPOSE_FILE")" up -d --build
fi

if [ $? -eq 0 ]; then
    echo "========================================================="
    echo "Docker containers started successfully!"
    echo ""
    echo "The application should be available at:"
    echo "http://localhost"
    echo ""
    echo "API is available at:"
    echo "http://localhost/api"
    echo ""
    echo "To view logs: docker compose logs -f"
    echo "To stop: docker compose down"
    echo "========================================================="
else
    echo "Failed to start Docker containers. Please check the logs."
    exit 1
fi

# Note about agent
echo "NOTE: The agent component must be installed and run separately on the"
echo "monitoring machine(s). It cannot be containerized with the rest of the"
echo "application since it needs access to the local network for SNMP scanning."
echo ""
echo "To set up the agent, run the setup_agent.sh script on each monitoring machine."