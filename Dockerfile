FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV USER=kali
ENV HOME=/home/kali

# ============================================================
# KALI LINUX + XFCE + VNC + NOVNC
# ============================================================

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        kali-desktop-xfce \
        kali-defaults-desktop \
        tigervnc-standalone-server \
        novnc \
        websockify \
        dbus-x11 \
        dbus-user-session \
        x11-xserver-utils \
        x11-utils \
        xterm \
        xfce4-terminal \
        sudo \
        curl \
        wget \
        git \
        vim \
        nano \
        net-tools \
        procps \
        psmisc \
        iproute2 \
        ca-certificates \
        gnupg \
        openssl \
        xz-utils \
        firefox-esr \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# USUÁRIO KALI
# ============================================================

RUN useradd -m -s /bin/bash kali \
    && echo "kali ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kali \
    && chmod 0440 /etc/sudoers.d/kali


# ============================================================
# CONFIGURAÇÃO DO XFCE
# ============================================================

RUN mkdir -p /home/kali/.config/xfce4 \
    && mkdir -p /home/kali/.config/tigervnc \
    && mkdir -p /home/kali/.config/autostart


# ============================================================
# TIGERVNC XSTARTUP
# ============================================================

RUN cat > /home/kali/.config/tigervnc/xstartup <<'EOF'
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export DISPLAY=:1
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export XDG_CONFIG_DIRS=/etc/xdg/xdg-xfce:/etc/xdg
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share:/usr/local/share

if [ -f "$HOME/.Xresources" ]; then
    xrdb "$HOME/.Xresources"
fi

exec dbus-launch --exit-with-session startxfce4
EOF

RUN chmod +x /home/kali/.config/tigervnc/xstartup


# ============================================================
# TIGERVNC CONFIG
# ============================================================

RUN cat > /home/kali/.config/tigervnc/config <<'EOF'
geometry=1920x1080
depth=24
localhost=no
SecurityTypes=None
EOF


# ============================================================
# NÃO INICIAR NAVEGADORES AUTOMATICAMENTE
# ============================================================

RUN rm -f /home/kali/.config/autostart/*firefox*.desktop \
          /home/kali/.config/autostart/*tor*.desktop \
          /etc/xdg/autostart/*firefox*.desktop \
          /etc/xdg/autostart/*tor*.desktop \
    || true


# ============================================================
# TOR BROWSER
# ============================================================

RUN cd /tmp \
    && wget -q \
       https://archive.torproject.org/tor-package-archive/torbrowser/14.0.9/tor-browser-linux-x86_64-14.0.9.tar.xz \
       -O tor-browser.tar.xz \
    && tar -xJf tor-browser.tar.xz -C /opt \
    && rm -f tor-browser.tar.xz \
    && test -f /opt/tor-browser/Browser/start-tor-browser \
    && chmod +x /opt/tor-browser/Browser/start-tor-browser \
    && chown -R kali:kali /opt/tor-browser


# ============================================================
# ATALHO DO TOR BROWSER
# ============================================================

RUN ln -sf /opt/tor-browser/Browser/start-tor-browser \
    /usr/local/bin/tor-browser


# ============================================================
# DESKTOP DIRECTORY
# ============================================================

RUN cat > /home/kali/.Xresources <<'EOF'
XTerm*faceName: Monospace
XTerm*faceSize: 11
XTerm*background: black
XTerm*foreground: white
EOF


# ============================================================
# PERMISSÕES
# ============================================================

RUN chown -R kali:kali /home/kali \
    && touch /home/kali/.Xauthority \
    && chown kali:kali /home/kali/.Xauthority


# ============================================================
# SCRIPT PRINCIPAL
# ============================================================

RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -e

export DISPLAY=:1
export HOME=/home/kali

echo "=========================================="
echo "       KALI LINUX 2026 - XFCE"
echo "=========================================="
echo ""
echo "Usuário: kali"
echo "Desktop: XFCE"
echo "Display: :1"
echo ""


# ============================================================
# LIMPEZA
# ============================================================

echo "[1/5] Limpando sessões antigas..."

runuser -u kali -- \
    env HOME=/home/kali \
        USER=kali \
        LOGNAME=kali \
        vncserver -kill :1 \
        >/dev/null 2>&1 || true

rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

rm -rf /home/kali/.vnc

mkdir -p /home/kali/.config/tigervnc

chown -R kali:kali /home/kali


# ============================================================
# TIGERVNC
# ============================================================

echo "[2/5] Iniciando TigerVNC..."

runuser -u kali -- \
    env HOME=/home/kali \
        USER=kali \
        LOGNAME=kali \
        DISPLAY=:1 \
        vncserver :1 \
            -geometry 1920x1080 \
            -depth 24 \
            -localhost no \
            -SecurityTypes None \
            --I-KNOW-THIS-IS-INSECURE


echo ""
echo "TigerVNC iniciado."
echo "Porta: 5901"
echo ""


# ============================================================
# AGUARDA DESKTOP
# ============================================================

echo "[3/5] Aguardando XFCE..."

sleep 5

echo ""
echo "Processos gráficos:"
echo "------------------------------------------"

ps aux | grep -E \
    "Xtigervnc|xfce4-session|xfdesktop|xfwm4|xfce4-panel" \
    | grep -v grep || true

echo "------------------------------------------"
echo ""


# ============================================================
# CERTIFICADO
# ============================================================

echo "[4/5] Preparando certificado SSL..."

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


# ============================================================
# NOVNC
# ============================================================

echo "[5/5] Iniciando noVNC..."

websockify \
    --web=/usr/share/novnc/ \
    --cert=/etc/novnc/self.pem \
    0.0.0.0:6080 \
    127.0.0.1:5901 &

NOVNC_PID=$!


# ============================================================
# STATUS
# ============================================================

sleep 3

echo ""
echo "=========================================="
echo "          KALI LINUX ONLINE"
echo "=========================================="
echo ""
echo "Desktop:       XFCE"
echo "Resolução:     1920x1080"
echo "Usuário:       kali"
echo ""
echo "VNC:           5901"
echo "noVNC:         6080"
echo ""
echo "Firefox:       instalado"
echo "Tor Browser:   instalado"
echo ""
echo "Navegadores:"
echo "NÃO iniciados automaticamente"
echo ""
echo "=========================================="
echo ""


# ============================================================
# MONITORAMENTO
# ============================================================

wait $NOVNC_PID
EOF


RUN chmod +x /usr/local/bin/start-desktop.sh


# ============================================================
# PORTAS
# ============================================================

EXPOSE 5901
EXPOSE 6080


# ============================================================
# START
# ============================================================

CMD ["/usr/local/bin/start-desktop.sh"]
