FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

# ============================================================
# PACOTES
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
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# USUÁRIO KALI
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
# OPENBOX
# ============================================================

RUN mkdir -p /home/kali/.config/openbox \
    && cat > /home/kali/.config/openbox/rc.xml <<'EOF'
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
# AUTOSTART DO OPENBOX
# ============================================================

RUN cat > /home/kali/.config/openbox/autostart <<'EOF'
#!/bin/sh

# Variáveis da sessão
export DISPLAY=:1
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=Openbox

# Fundo da área de trabalho
xsetroot -solid "#202020"

# Terminal para confirmar que o desktop está funcionando
xterm \
    -geometry 100x30+20+20 \
    -title "Kali Linux" &

# Aguarda o Openbox carregar
sleep 3

# Inicia o Tor Browser
/opt/tor-browser/Browser/start-tor-browser &

EOF

RUN chmod +x /home/kali/.config/openbox/autostart


# ============================================================
# TIGERVNC
# ============================================================

RUN mkdir -p /home/kali/.config/tigervnc \
    && cat > /home/kali/.config/tigervnc/xstartup <<'EOF'
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export DISPLAY=:1
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=Openbox

# Recursos X
if [ -f "$HOME/.Xresources" ]; then
    xrdb "$HOME/.Xresources"
fi

# Inicia o Openbox
exec dbus-launch --exit-with-session openbox-session
EOF

RUN chmod +x /home/kali/.config/tigervnc/xstartup


# ============================================================
# CONFIGURAÇÃO TIGERVNC
# ============================================================

RUN cat > /home/kali/.config/tigervnc/config <<'EOF'
geometry=1920x1080
depth=24
localhost=no
SecurityTypes=None
EOF


# ============================================================
# PERMISSÕES
# ============================================================

RUN chown -R kali:kali /home/kali \
    && mkdir -p /home/kali/.vnc \
    && rm -rf /home/kali/.vnc \
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
echo " INICIANDO KALI LINUX"
echo "=========================================="

echo "Usuário: kali"
echo "Display: $DISPLAY"

# ------------------------------------------------------------
# Limpeza
# ------------------------------------------------------------

echo "Limpando sessões anteriores..."

runuser -u kali -- \
    env HOME=/home/kali \
    USER=kali \
    LOGNAME=kali \
    vncserver -kill :1 >/dev/null 2>&1 || true

rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

rm -rf /home/kali/.vnc

mkdir -p /home/kali/.config/tigervnc

chown -R kali:kali /home/kali/.config


# ------------------------------------------------------------
# TigerVNC
# ------------------------------------------------------------

echo "=========================================="
echo " INICIANDO TIGERVNC"
echo "=========================================="

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
echo "TigerVNC iniciado!"
echo "Porta: 5901"
echo ""


# ------------------------------------------------------------
# Verificação
# ------------------------------------------------------------

sleep 3

echo "=========================================="
echo " PROCESSOS GRÁFICOS"
echo "=========================================="

ps aux | grep -E "Xtigervnc|openbox|xterm" | grep -v grep || true

echo ""


# ------------------------------------------------------------
# Certificado noVNC
# ------------------------------------------------------------

mkdir -p /etc/novnc

if [ ! -f /etc/novnc/self.pem ]; then

    echo "Gerando certificado SSL..."

    openssl req \
        -new \
        -x509 \
        -days 365 \
        -nodes \
        -subj "/C=BR/ST=DF/L=Brasilia/O=Kali/CN=localhost" \
        -out /etc/novnc/self.pem \
        -keyout /etc/novnc/self.pem

fi


# ------------------------------------------------------------
# noVNC
# ------------------------------------------------------------

echo "=========================================="
echo " INICIANDO NOVNC"
echo "=========================================="

websockify \
    --web=/usr/share/novnc/ \
    --cert=/etc/novnc/self.pem \
    6080 \
    localhost:5901 &

NOVNC_PID=$!


# ------------------------------------------------------------
# Status
# ------------------------------------------------------------

sleep 2

echo ""
echo "=========================================="
echo " KALI ONLINE"
echo "=========================================="
echo ""
echo "VNC:    5901"
echo "noVNC:  6080"
echo "PID:    $NOVNC_PID"
echo ""
echo "Desktop: Openbox"
echo "Terminal: xterm"
echo "Browser: Tor Browser"
echo ""
echo "=========================================="


# ------------------------------------------------------------
# Mantém container ativo
# ------------------------------------------------------------

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
