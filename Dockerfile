# ============================
# Stage 1: Build Luanti
# ============================
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git build-essential cmake pkg-config \
    libirrlicht-dev libjpeg-dev libpng-dev \
    libxxf86vm-dev libgl1-mesa-dev libopenal-dev \
    libvorbis-dev libsqlite3-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /luanti

# Clone Luanti source
RUN git clone --depth=1 https://github.com/luanti-org/luanti.git .

# Build Luanti
RUN mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# ============================
# Stage 2: Runtime
# ============================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    x11-xserver-utils pulseaudio dbus-x11 wget \
    libirrlicht1.8 libopenal1 libvorbisfile3 \
    libgl1-mesa-dri libgl1-mesa-glx libglu1-mesa \
    xvfb turboVNC novnc websockify imagemagick \
    && rm -rf /var/lib/apt/lists/*

# Copy Luanti binary
COPY --from=builder /luanti/build/bin/luanti /usr/local/bin/luanti

# --- Add PWA assets ---
RUN mkdir -p /usr/share/novnc/icons

# Download official Luanti logo (Minetest logo) SVG
RUN wget -O /usr/share/novnc/icons/luanti.svg \
    https://upload.wikimedia.org/wikipedia/commons/5/55/Minetest_logo.svg

# Convert SVG to PNG for PWA icons
RUN convert /usr/share/novnc/icons/luanti.svg -resize 192x192 /usr/share/novnc/icons/icon-192.png && \
    convert /usr/share/novnc/icons/luanti.svg -resize 512x512 /usr/share/novnc/icons/icon-512.png && \
    rm /usr/share/novnc/icons/luanti.svg

# Create PWA manifest
COPY <<'EOF' /usr/share/novnc/manifest.json
{
  "name": "Luanti Web Client",
  "short_name": "Luanti",
  "start_url": "/vnc.html",
  "display": "standalone",
  "background_color": "#222",
  "theme_color": "#444",
  "icons": [
    {
      "src": "icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOF

# Create service worker for caching
COPY <<'EOF' /usr/share/novnc/sw.js
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open('luanti-cache').then(cache => {
      return cache.addAll([
        '/vnc.html',
        '/manifest.json'
      ]);
    })
  );
});
self.addEventListener('fetch', e => {
  e.respondWith(
    caches.match(e.request).then(resp => resp || fetch(e.request))
  );
});
EOF

# Expose HTTP port for noVNC
EXPOSE 8080

# Start Luanti in virtual X with TurboVNC + websockify + PulseAudio
CMD bash -c "\
    export DISPLAY=:0 && \
    Xvfb :0 -screen 0 1280x720x24 & \
    sleep 2 && \
    /opt/TurboVNC/bin/vncserver :0 -SecurityTypes None & \
    websockify --web=/usr/share/novnc/ 8080 localhost:5900 & \
    pulseaudio --start && \
    DISPLAY=:0 luanti"
