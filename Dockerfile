FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV HOME=/home/kali
ENV USER=kali
ENV LOGNAME=kali

# ============================================================
# KALI ROLLING + XFCE + VNC + NOVNC
# ============================================================

RUN apt-get update \
    && apt-get full-upgrade -y \
    && apt-get install --no-install-recommends -y \
        kali-desktop-xfce \
        tigervnc-standalone-server \
        novnc \
        websockify \
        dbus-x11 \
        x11-xserver-utils \
        x11-utils \
        xterm \
        sudo \
        curl \
        wget \
        git \
        vim \
        nano \
        net-tools \
        procps \
        openssl \
        ca-certificates \
        xz-utils \
        firefox-esr \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# USUÁRIO KALI
# ============================================================

RUN useradd \
        --create-home \
        --shell /bin/bash \
        kali \
    && echo "kali ALL=(ALL) NOPASSWD:ALL" \
        > /etc/sudoers.d/kali \
    && chmod 0440 /etc/sudoers.d/kali


# ============================================================
# TOR BROWSER
# ============================================================

RUN cd /tmp \
    && wget -q \
       https://archive.torproject.org/tor-package-archive/torbrowser/14.0.9/tor-browser-linux-x86_64-14.0.9.tar.xz \
       -O tor-browser.tar.xz \
    && tar -xJf tor-browser.tar.xz -C /opt \
    && rm -f tor-browser.tar.xz \
    && test -x /opt/tor-browser/Browser/start-tor-browser \
    && chown -R kali:kali /opt/tor-browser


# ============================================================
# DIRETÓRIOS DO KALI
# ============================================================

RUN mkdir -p \
        /home/kali/.config/tigervnc \
        /home/kali/.config/autostart \
        /etc/novnc \
    && chown -R kali:kali /home/kali


# ============================================================
# TIGERVNC XSTARTUP
# ============================================================

RUN cat > /home/kali/.config/tigervnc/xstartup <<'EOF'
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export DISPLAY=:1
export HOME=/home/kali
export USER=kali
export LOGNAME=kali

export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export XDG_SESSION_TYPE=x11

if [ -f "$HOME/.Xresources" ]; then
    xrdb "$HOME/.Xresources"
fi

# Inicia o desktop XFCE completo
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
# TOR NÃO INICIA AUTOMATICAMENTE
# FIREFOX NÃO INICIA AUTOMATICAMENTE
# ============================================================

RUN rm -f \
        /home/kali/.config/autostart/*firefox* \
        /home/kali/.config/autostart/*tor* \
        /etc/xdg/autostart/*firefox* \
        /etc/xdg/autostart/*tor* \
    2>/dev/null || true


# ============================================================
# PERMISSÕES
# ============================================================

RUN touch /home/kali/.Xauthority \
    && chown -R kali:kali /home/kali


# ============================================================
# SCRIPT DE INICIALIZAÇÃO
# ============================================================

RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -e

export DISPLAY=:1

echo ""
echo "=============================================="
echo "        KALI LINUX ROLLING + XFCE"
echo "=============================================="
echo ""
echo "Usuário : kali"
echo "Desktop : XFCE"
echo "Display : :1"
echo ""


# ============================================================
# LIMPA SESSÃO ANTERIOR
# ============================================================

echo "[1/4] Limpando sessão anterior..."

runuser -u kali -- \
    env \
        HOME=/home/kali \
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
# INICIA TIGERVNC
# ============================================================

echo ""
echo "[2/4] Iniciando TigerVNC..."

runuser -u kali -- \
    env \
        HOME=/home/kali \
        USER=kali \
        LOGNAME=kali \
        DISPLAY=:1 \
    vncserver :1 \
        -geometry 1920x1080 \
        -depth 24 \
        -localhost no \
        -SecurityTypes None \
        -xstartup /home/kali/.config/tigervnc/xstartup \
        --I-KNOW-THIS-IS-INSECURE

echo ""
echo "TigerVNC iniciado na porta 5901"


# ============================================================
# AGUARDA XFCE
# ============================================================

sleep 5

echo ""
echo "=============================================="
echo "        PROCESSOS DO DESKTOP"
echo "=============================================="

ps aux | grep -E \
    "Xtigervnc|xfce4-session|xfdesktop|xfwm4|xfce4-panel" \
    | grep -v grep || true


# ============================================================
# CERTIFICADO NOVNC
# ============================================================

echo ""
echo "[3/4] Preparando certificado noVNC..."

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

echo ""
echo "[4/4] Iniciando noVNC..."

websockify \
    --web=/usr/share/novnc/ \
    --cert=/etc/novnc/self.pem \
    0.0.0.0:6080 \
    127.0.0.1:5901 &

NOVNC_PID=$!


# ============================================================
# STATUS
# ============================================================

sleep 2

echo ""
echo "=============================================="
echo "           KALI LINUX ONLINE"
echo "=============================================="
echo ""
echo "Desktop  : XFCE"
echo "Resolucao: 1920x1080"
echo "Usuario  : kali"
echo "VNC      : 5901"
echo "noVNC    : 6080"
echo ""
echo "Firefox      : instalado"
echo "Tor Browser  : instalado"
echo "Auto-start   : DESATIVADO"
echo ""
echo "=============================================="
echo ""


# ============================================================
# MANTÉM CONTAINER ATIVO
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
