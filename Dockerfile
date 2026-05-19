# qBittorrent, OpenVPN and WireGuard, qbittorrentvpn
FROM debian:trixie-slim AS builder

WORKDIR /opt

# Install all build dependencies
RUN apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    jq \
    libssl-dev \
    pkg-config \
    qt6-base-dev \
    qt6-base-private-dev \
    qt6-tools-dev \
    unzip \
    zlib1g-dev

# Build Boost (static, selective libraries only)
RUN BOOST_VERSION=$(curl -s https://archives.boost.io/release/ \
        | grep -E 'href="[0-9]+\.[0-9]+\.[0-9]+/' \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
        | sort -V | tail -1) \
    && BOOST_VERSION_US=$(echo ${BOOST_VERSION} | tr '.' '_') \
    && BOOST_ARCHIVE="boost_${BOOST_VERSION_US}.tar.gz" \
    && BOOST_BASE_URL="https://archives.boost.io/release/${BOOST_VERSION}/source" \
    && curl -o /opt/${BOOST_ARCHIVE} -L ${BOOST_BASE_URL}/${BOOST_ARCHIVE} \
    && BOOST_SHA256=$(curl -sL ${BOOST_BASE_URL}/${BOOST_ARCHIVE}.json | jq -r '.sha256') \
    && echo "${BOOST_SHA256}  /opt/${BOOST_ARCHIVE}" | sha256sum -c - \
    && tar -xzf /opt/${BOOST_ARCHIVE} -C /opt \
    && cd /opt/boost_${BOOST_VERSION_US} \
    && ./bootstrap.sh --prefix=/usr \
    && ./b2 link=static --prefix=/usr install \
    && cd /opt \
    && rm -rf /opt/*

# Install Ninja
RUN NINJA_ASSETS=$(curl -sX GET "https://api.github.com/repos/ninja-build/ninja/releases" \
        | jq '.[] | select(.prerelease==false) | .assets_url' | head -n 1 | tr -d '"') \
    && NINJA_DOWNLOAD_URL=$(curl -sX GET ${NINJA_ASSETS} \
        | jq '.[] | select(.name | match("ninja-linux.zip";"i")) .browser_download_url' | tr -d '"') \
    && curl -o /opt/ninja-linux.zip -L ${NINJA_DOWNLOAD_URL} \
    && unzip /opt/ninja-linux.zip -d /opt \
    && mv /opt/ninja /usr/local/bin/ninja \
    && chmod +x /usr/local/bin/ninja \
    && rm -rf /opt/*

# Install cmake
RUN CMAKE_ASSETS=$(curl -sX GET "https://api.github.com/repos/Kitware/CMake/releases" \
        | jq '.[] | select(.prerelease==false) | .assets_url' | head -n 1 | tr -d '"') \
    && CMAKE_ASSETS_JSON=$(curl -sX GET ${CMAKE_ASSETS}) \
    && CMAKE_INSTALLER=$(echo "${CMAKE_ASSETS_JSON}" \
        | jq -r '.[] | select(.name | match("Linux-x86_64.sh";"i")) | .name') \
    && CMAKE_DOWNLOAD_URL=$(echo "${CMAKE_ASSETS_JSON}" \
        | jq -r '.[] | select(.name | match("Linux-x86_64.sh";"i")) | .browser_download_url') \
    && CMAKE_SHA256_URL=$(echo "${CMAKE_ASSETS_JSON}" \
        | jq -r '.[] | select(.name | endswith("-SHA-256.txt")) | .browser_download_url') \
    && curl -o /opt/${CMAKE_INSTALLER} -L ${CMAKE_DOWNLOAD_URL} \
    && cd /opt && curl -sL ${CMAKE_SHA256_URL} | grep "${CMAKE_INSTALLER}" | sha256sum -c - \
    && chmod +x /opt/${CMAKE_INSTALLER} \
    && /bin/bash /opt/${CMAKE_INSTALLER} --skip-license --prefix=/usr \
    && rm -rf /opt/*

# Compile libtorrent-rasterbar
RUN LIBTORRENT_DEFAULT_BRANCH=$(curl -sX GET "https://api.github.com/repos/arvidn/libtorrent" \
        | jq -r '.default_branch') \
    && LIBTORRENT_ASSETS_URL=$(curl -sX GET "https://api.github.com/repos/arvidn/libtorrent/releases" \
        | jq -r --arg branch "$LIBTORRENT_DEFAULT_BRANCH" \
        '[.[] | select(.prerelease == false and .target_commitish == $branch)] | first | .assets_url') \
    && LIBTORRENT_ASSET=$(curl -sX GET "${LIBTORRENT_ASSETS_URL}" \
        | jq -r '[.[] | select(.name | test("\\.tar\\.gz$"))] | first') \
    && LIBTORRENT_DOWNLOAD_URL=$(echo "${LIBTORRENT_ASSET}" | jq -r '.browser_download_url') \
    && LIBTORRENT_NAME=$(echo "${LIBTORRENT_ASSET}" | jq -r '.name') \
    && curl -o /opt/${LIBTORRENT_NAME} -L ${LIBTORRENT_DOWNLOAD_URL} \
    && tar -xzf /opt/${LIBTORRENT_NAME} \
    && rm /opt/${LIBTORRENT_NAME} \
    && cd /opt/libtorrent-* \
    && cmake -G Ninja -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_CXX_STANDARD=17 \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd /opt \
    && rm -rf /opt/*

# Compile qBittorrent-nox
RUN QBITTORRENT_RELEASE=$(curl -sX GET "https://api.github.com/repos/qbittorrent/qBittorrent/releases" \
        | jq -r '[.[] | select(.prerelease == false)] | first | .tag_name') \
    && curl -o /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz -L \
        "https://github.com/qbittorrent/qBittorrent/archive/${QBITTORRENT_RELEASE}.tar.gz" \
    && tar -xzf /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz \
    && rm /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz \
    && cd /opt/qBittorrent-${QBITTORRENT_RELEASE} \
    && cmake -G Ninja -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DGUI=OFF \
        -DCMAKE_CXX_STANDARD=17 \
        -DQT6=ON \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd /opt \
    && rm -rf /opt/*


FROM debian:trixie-slim AS runtime

RUN usermod -u 99 nobody

RUN mkdir -p /downloads /config/qBittorrent /etc/openvpn /etc/qbittorrent

# Install runtime dependencies
RUN echo "deb http://deb.debian.org/debian/ trixie non-free" > /etc/apt/sources.list.d/non-free-unrar.list \
    && printf 'Package: *\nPin: release a=non-free\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-non-free \
    && apt update \
    && apt -y upgrade \
    && apt -y install --no-install-recommends \
    ca-certificates \
    inetutils-ping \
    ipcalc \
    iproute2 \
    iptables \
    kmod \
    libqt6network6 \
    libqt6sql6 \
    libqt6xml6 \
    libssl3t64 \
    moreutils \
    net-tools \
    openresolv \
    openvpn \
    p7zip-full \
    procps \
    python3 \
    unrar \
    unzip \
    wireguard-tools \
    zip \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Remove src_valid_mark from wg-quick
RUN sed -i /net\.ipv4\.conf\.all\.src_valid_mark/d `which wg-quick`

# Copy compiled artifacts from builder
COPY --from=builder /usr/local/bin/qbittorrent-nox /usr/local/bin/qbittorrent-nox
COPY --from=builder /usr/local/lib/libtorrent-rasterbar.so* /usr/local/lib/
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && ldconfig

VOLUME /config /downloads

COPY openvpn/ /etc/openvpn/
COPY qbittorrent/ /etc/qbittorrent/

RUN chmod +x /etc/qbittorrent/*.sh /etc/qbittorrent/*.init /etc/openvpn/*.sh

EXPOSE 8080
EXPOSE 8999
EXPOSE 8999/udp
CMD ["/bin/bash", "/etc/openvpn/start.sh"]
