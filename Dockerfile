ARG VERSION_TAG
FROM --platform=$TARGETOS/$TARGETARCH ghcr.io/pterodactyl/panel:${VERSION_TAG}

# Set the Working Directory
WORKDIR /app

# Install necessary packages
RUN apk update && apk add --no-cache \
    unzip \
    zip \
    curl \
    git \
    bash \
    wget \
    nodejs \
    npm \
    coreutils \
    build-base \
    musl-dev \
    libgcc \
    openssl \
    openssl-dev \
    linux-headers \
    ncurses \
    rsync \
    inotify-tools

# Install yarn and Pterodactyl dependencies, as well as update browserlist
RUN for i in {1..3}; do \
        npm install -g yarn && \
        yarn --network-timeout 120000 && \
        npx update-browserslist-db@latest && \
        break || \
        echo "Attempt $i failed! Retrying..." && \
        sleep 10; \
    done

# Download and unzip the latest Blueprint release
RUN wget $(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4) -O blueprint.zip \
    && unzip -o blueprint.zip -d /app \
    && touch /.dockerenv \
    && rm blueprint.zip

# Required for tput (used in blueprint.sh)
ENV TERM=xterm

# Set Blueprint user and permissions
COPY .helpers/.blueprintrc /app/.blueprintrc

# Make the script executable and run it
RUN chmod +x blueprint.sh \
    && bash blueprint.sh

# Create directory for blueprint extensions
RUN mkdir -p /blueprint_extensions

# Copy listen.sh from .helpers directory
COPY .helpers/listen.sh /listen.sh
RUN chmod +x /listen.sh

# Append listener and seeder to supervisord
RUN echo "" >> /etc/supervisord.conf && \
    cat >> /etc/supervisord.conf <<'EOF'
[program:database-seeder]
command=/bin/bash -c 'while ! [[ $(/usr/local/bin/php /app/artisan db:monitor) =~ OK ]]; do /bin/sleep 5; done && /usr/local/bin/php /app/artisan db:seed --class=BlueprintSeeder --force'
user=nginx
autostart=true
autorestart=false
startsecs=0

[program:listener]
command=/listen.sh
user=root
autostart=true
autorestart=true
EOF
