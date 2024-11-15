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

# Make blueprint.sh set ownership to nginx:nginx
RUN sed -i -E \
    -e "s|OWNERSHIP=\"www-data:www-data\" #;|OWNERSHIP=\"nginx:nginx\" #;|g" \
    -e "s|WEBUSER=\"www-data\" #;|WEBUSER=\"nginx\" #;|g" \
    blueprint.sh

# Make the script executable and run it
RUN chmod +x blueprint.sh \
    && bash blueprint.sh

# Create directory for blueprint extensions
RUN mkdir -p /blueprint_extensions /app

# Copy listen.sh from .helpers directory
COPY .helpers/listen.sh /listen.sh
RUN chmod +x /listen.sh

# Set CMD to run the listen script in the background and start supervisord
CMD /listen.sh & exec supervisord -n -c /etc/supervisord.conf