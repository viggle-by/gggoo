# ============================
# Dockerfile: Luanti Web Client
# ============================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# ----------------------------
# Install dependencies
# ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ make libc6-dev cmake \
    libpng-dev libjpeg-dev libgl1-mesa-dev libgl1-mesa-dri \
    libsqlite3-dev libogg-dev libvorbis-dev libopenal-dev \
    libcurl4-gnutls-dev libfreetype6-dev zlib1g-dev \
    libgmp-dev libjsoncpp-dev libzstd-dev libluajit-5.1-dev \
    gettext libsdl2-dev \
    xvfb tigervnc-standalone-server novnc python3-websockify pulseaudio \
    git ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Clone and build Luanti
# ----------------------------
RUN git clone --depth 1 https://github.com/luanti-org/luanti
WORKDIR /app/luanti
RUN cmake . -DRUN_IN_PLACE=TRUE && make -j$(nproc)

# ----------------------------
# Setup noVNC web client
# ----------------------------
WORKDIR /usr/share/novnc
RUN git clone https://github.com/novnc/noVNC.git . && git clone https://github.com/novnc/websockify websockify

# Expose web port
EXPOSE 8080

# ----------------------------
# Start Luanti in virtual X + VNC + PulseAudio
# ----------------------------
CMD bash -c "\
    export DISPLAY=:0 && \
    Xvfb :0 -screen 0 1280x720x24 & \
    sleep 2 && \
    vncserver :0 -geometry 1280x720 -SecurityTypes None & \
    websockify --web=/usr/share/novnc 8080 localhost:5900 & \
    pulseaudio --start && \
    DISPLAY=:0 /app/luanti/bin/luanti"
