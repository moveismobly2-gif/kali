FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

# ============================================================
# Pacotes base
# ============================================================

RUN apt-get update && apt-get install --no-install-recommends -y \
    tigervnc-standalone-server \
    novnc \
    websockify \
    sudo \
    xterm \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    gnupg \
    ca-certificates \
    openssl \
    xz-utils \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    openbox \
    obconf \
    tint2 \
    pcmanfm \
    xinit \
    firefox-esr \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Instalação do Tor Browser
# ============================================================

RUN mkdir -p /opt/tor-browser \
    && cd /tmp \
    && wget -q \
       https://archive.torproject.org/tor-package-archive/torbrowser/14.0.9/tor-browser-linux-x86_64-14.0.9.tar.xz \
       -O tor-browser.tar.xz \
    && tar -xJf tor-browser.tar.xz -C /opt \
    && rm -f tor-browser.tar.xz \
    && test -f /opt/tor-browser/Browser/start-tor-browser \
    && ln -sf /opt/tor-browser/Browser/start-tor-browser /usr/local/bin/tor-browser \
    && chmod +x /opt/tor-browser/Browser/start-tor-browser


# ============================================================
# Configuração do Openbox
# ============================================================

RUN mkdir -p /root/.config/openbox \
    && cat > /root/.config/openbox/rc.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<openbox_config xmlns="http://openbox.org/3.4/rc">

  <applications>

    <application class="*">
      <decor>yes</decor>
    </application>

  </applications>

</openbox_config>
EOF


# ============================================================
# Configuração do VNC
# ============================================================

RUN mkdir -p /root/.vnc \
    && cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh

export DISPLAY=:1
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=Openbox

xrdb "$HOME/.Xresources" 2>/dev/null || true

dbus-launch --exit-with-session openbox-session &

sleep 2

tor-browser --no-sandbox &

wait
EOF

RUN chmod +x /root/.vnc/xstartup \
    && touch /root/.Xauthority


# ============================================================
# Script de inicialização
# ============================================================

RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -e

export DISPLAY=:1

echo "=========================================="
echo " Iniciando ambiente gráfico"
echo "=========================================="

# Remove sessões antigas caso existam
vncserver -kill :1 >/dev/null 2>&1 || true

rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

# Inicia o servidor VNC
vncserver :1 \
    -geometry 1920x1080 \
    -depth 24 \
    -localhost no \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE

echo "VNC iniciado na porta 5901"

# Gera certificado SSL para o noVNC
mkdir -p /etc/novnc

if [ ! -f /etc/novnc/self.pem ]; then
    openssl req \
        -new \
        -x509 \
        -days 365 \
        -nodes \
        -subj "/C=BR/ST=DF/L=Brasilia/O=Kali/CN=localhost" \
        -out /etc/novnc/self.pem \
        -keyout /etc/novnc/self.pem
fi

echo "Iniciando noVNC..."

websockify \
    --web=/usr/share/novnc/ \
    --cert=/etc/novnc/self.pem \
    6080 \
    localhost:5901 &

echo "=========================================="
echo " Ambiente iniciado!"
echo ""
echo " VNC:   :5901"
echo " noVNC: :6080"
echo "=========================================="

# Mantém o container rodando
wait
EOF

RUN chmod +x /usr/local/bin/start-desktop.sh


# ============================================================
# Portas
# ============================================================

EXPOSE 5901
EXPOSE 6080


# ============================================================
# Inicialização
# ============================================================

CMD ["/usr/local/bin/start-desktop.sh"]
