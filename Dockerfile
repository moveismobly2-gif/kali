FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV USER=kali
ENV HOME=/home/kali

# ============================================================
# ATUALIZAÇÃO DO KALI + DESKTOP XFCE
# ============================================================

RUN apt-get update \
    && apt-get full-upgrade -y \
    && apt-get install -y \
        kali-desktop-xfce \
        kali-linux-default \
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
        firefox-esr \
        procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# USUÁRIO
# ============================================================

RUN useradd -m -s /bin/bash kali \
    && echo "kali ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kali \
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
    && test -f /opt/tor-browser/Browser/start-tor-browser \
    && chmod +x /opt/tor-browser/Browser/start-tor-browser \
    && chown -R kali:kali /opt/tor-browser


# ============================================================
# CONFIGURAÇÃO TIGERVNC
# ============================================================

RUN mkdir -p /home/kali/.config/tigervnc \
    && cat > /home/kali/.config/tigervnc/xstartup <<'EOF'
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export DISPLAY=:1
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce

if [ -f "$HOME/.Xresources" ]; then
    xrdb "$HOME/.Xresources"
fi

# Inicia o desktop XFCE oficial do Kali
exec dbus-launch --exit-with-session startxfce4
EOF

RUN chmod +x /home/kali/.config/tigervnc/xstartup


# ============================================================
# CONFIGURAÇÃO DO TIGERVNC
# ============================================================

RUN cat > /home/kali/.config/tigervnc/config <<'EOF'
geometry=1920x1080
depth=24
localhost=no
SecurityTypes=None
EOF


# ============================================================
# NÃO ABRIR NENHUM NAVEGADOR AUTOMATICAMENTE
# ============================================================

RUN mkdir -p /home/kali/.config/autostart \
    && rm -f /home/kali/.config/autostart/*browser*.desktop \
    && rm -f /etc/xdg/autostart/*firefox*.desktop \
    && rm -f /etc/xdg/autostart/*tor*.desktop \
    && true


# ============================================================
# PERMISSÕES
# ============================================================

RUN chown -R kali:kali /home/kali \
    && touch /home/kali/.Xauthority \
    && chown kali:kali /home/kali/.Xauthority


# ============================================================
# SCRIPT DE INICIALIZAÇÃO
# ============================================================

RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -e

export DISPLAY=:1

echo "=========================================="
echo "       KALI LINUX 2026 - XFCE"
echo "=========================================="

echo "Usuário: kali"
echo "Display: :1"
echo ""


# ============================================================
# LIMPEZA
# ============================================================

echo "[1/4] Limpando sessão anterior..."

runuser -u kali -- \
    env HOME=/home/kali \
        USER=kali \
        LOGNAME=kali \
        vncserver -kill :1 >/dev/null 2>&1 || true

rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

rm -rf /home/kali/.vnc

mkdir -p /home/kali/.config/tigervnc

chown -R kali:kali /home/kali


# ============================================================
# TIGERVNC
# ============================================================

echo "[2/4] Iniciando TigerVNC..."

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
echo "Porta interna: 5901"
echo ""


# ============================================================
# AGUARDA XFCE
# ============================================================

sleep 5

echo "=========================================="
echo " PROCESSOS DO DESKTOP"
echo "=========================================="

ps aux | grep -E \
    "Xtigervnc|xfce4-session|xfdesktop|xfwm4|xfce4-panel" \
    | grep -v grep || true

echo ""


# ============================================================
# CERTIFICADO NOVNC
# ============================================================

echo "[3/4] Preparando noVNC..."

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

echo "[4/4] Iniciando noVNC..."

websockify \
    --web=/usr/share/novnc/ \
    --cert=/etc/novnc/self.pem \
    6080 \
    localhost:5901 &

NOVNC_PID=$!


# ============================================================
# STATUS
# ============================================================

sleep 2

echo ""
echo "=========================================="
echo "       KALI LINUX ONLINE"
echo "=========================================="
echo ""
echo "Desktop: XFCE"
echo "Resolução: 1920x1080"
echo "VNC: 5901"
echo "noVNC: 6080"
echo ""
echo "Firefox: instalado"
echo "Tor Browser: instalado"
echo "Navegadores: NÃO iniciados automaticamente"
echo ""
echo "=========================================="


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
# INICIALIZAÇÃO
# ============================================================

CMD ["/usr/local/bin/start-desktop.sh"]
