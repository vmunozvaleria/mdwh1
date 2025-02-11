FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive 

# Install dependencies
RUN apt update && apt install -y \
    git curl build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget llvm \
    libncurses5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev python3-pip python3.11 python3.11-venv redis \
    && apt clean && rm -rf /var/lib/apt/lists/*

# Clone Middleware repository
WORKDIR /app
RUN git clone https://github.com/middlewarehq/middleware.git .

# Generate encryption keys
WORKDIR /app/setup_utils
RUN chmod +x generate_config_ini.sh && ./generate_config_ini.sh

# Setup backend
WORKDIR /app/backend
RUN python3.11 -m venv venv && . venv/bin/activate && \
    pip install -r requirements.txt -r dev-requirements.txt

# Create .env file
RUN echo "REDIS_HOST=localhost" >> .env && \
    echo "REDIS_PORT=6385" >> .env && \
    echo "ANALYTICS_SERVER_PORT=9696" >> .env && \
    echo "SYNC_SERVER_PORT=9697" >> .env && \
    echo "DEFAULT_SYNC_DAYS=31" >> .env

# Install Node.js, yarn, and frontend dependencies
WORKDIR /app/web-server
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && \
    apt install -y nodejs && \
    npm install --global yarn && \
    yarn

# Expose ports
EXPOSE 3333 9696 9697

# Start services
CMD service redis-server start && \
    cd /app/backend && . venv/bin/activate && \
    flask --app analytics_server/app --debug run --port 9696 & \
    flask --app sync_server/sync_app --debug run --port 9697 & \
    cd /app/web-server && yarn dev
