FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y \
    nodejs \
    python3 \
    python3-pip \
    python3-venv \
    php-cli \
    php-common \
    php-curl \
    php-mbstring \
    php-xml \
    php-zip \
    php-mysql \
    php-sqlite3 \
    php-pgsql \
    php-gd \
    php-imagick \
    php-intl \
    php-bcmath \
    php-soap \
    php-redis \
    php-memcached \
    php-xdebug \
    composer \
    ffmpeg \
    gettext \
    git \
    jq \
    gosu \
    sudo \
    ripgrep \
    fd-find \
    bat \
    tree \
    htop \
    procps \
    unzip \
    zip \
    tar \
    xz-utils \
    openssh-client \
    rsync \
    vim \
    nano \
    less \
    postgresql-client \
    default-mysql-client \
    redis-tools \
    sqlite3 \
    netcat-openbsd \
    dnsutils \
    iputils-ping \
    net-tools \
    build-essential \
    pkg-config \
    libssl-dev \
    gh \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && ln -s /usr/bin/batcat /usr/local/bin/bat

RUN ARCH="$(dpkg --print-architecture)" && \
    if [ "$ARCH" = "arm64" ]; then GOARCH="arm64"; else GOARCH="amd64"; fi && \
    curl -fsSL "https://go.dev/dl/go1.25.6.linux-${GOARCH}.tar.gz" | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# Docker CLI + Compose plugin (for --docker socket passthrough)
RUN ARCH="$(dpkg --print-architecture)" && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg \
    && echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --break-system-packages --no-cache-dir \
    pillow \
    numpy \
    pandas \
    requests \
    httpx \
    beautifulsoup4 \
    lxml \
    pyyaml \
    python-dotenv \
    rich \
    ipython \
    pytest \
    black \
    ruff \
    mypy \
    fastapi \
    uvicorn \
    pydantic \
    sqlalchemy \
    matplotlib \
    tqdm \
    click \
    typer \
    openpyxl

# PHP / WordPress tooling installed via composer global (shared location, on PATH)
ENV COMPOSER_HOME=/usr/local/lib/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="/usr/local/lib/composer/vendor/bin:${PATH}"
RUN composer global config --no-interaction allow-plugins.dealerdirect/phpcodesniffer-composer-installer true \
    && composer global require --no-interaction \
        squizlabs/php_codesniffer \
        wp-coding-standards/wpcs \
        phpcompatibility/phpcompatibility-wp \
        dealerdirect/phpcodesniffer-composer-installer \
        phpunit/phpunit \
        phpstan/phpstan \
        vimeo/psalm \
        friendsofphp/php-cs-fixer \
    && chmod -R a+rwX /usr/local/lib/composer

# wp-cli (WordPress CLI) as a phar
RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# symfony-cli
RUN curl -fsSL https://get.symfony.com/cli/installer | bash \
    && mv /root/.symfony5/bin/symfony /usr/local/bin/symfony \
    && rm -rf /root/.symfony5

RUN npm install -g @anthropic-ai/claude-code

RUN npm install -g @playwright/mcp \
    typescript \
    tsx \
    ts-node \
    pnpm \
    yarn \
    prettier \
    eslint

RUN if [ "$(dpkg --print-architecture)" = "arm64" ]; then \
        npx playwright install --with-deps chromium; \
    else \
        npx playwright install --with-deps chrome; \
    fi

RUN git config --global --add safe.directory '*'
RUN echo "ALL ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
