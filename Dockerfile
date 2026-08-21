FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive

# Instalação base
RUN apt update -y && apt install --no-install-recommends -y \
    tigervnc-standalone-server \
    novnc \
    websockify \
    sudo \
    xterm \
    init \
    systemd \
    snapd \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    gnupg \
    software-properties-common \
    ca-certificates \
    firefox-esr

RUN apt update -y && apt install -y \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps

# Instalação do Tor Browser (versão mais recente)
RUN wget -qO- https://www.torproject.org/dist/torbrowser/14.0.9/tor-browser-linux-x86_64-14.0.9.tar.xz | tar -xJ -C /opt \
    && ln -s /opt/tor-browser/Browser/start-tor-browser /usr/local/bin/tor-browser \
    && chmod +x /usr/local/bin/tor-browser

# Instalação do Openbox (gerenciador de janelas leve)
RUN apt update -y && apt install --no-install-recommends -y \
    openbox \
    obconf \
    tint2 \
    pcmanfm \
    xinit \
    && apt clean

# Configuração do Openbox
RUN mkdir -p /root/.config/openbox \
    && echo '<?xml version="1.0" encoding="UTF-8"?>' > /root/.config/openbox/rc.xml \
    && echo '<openbox_config xmlns="http://openbox.org/3.4/rc">' >> /root/.config/openbox/rc.xml \
    && echo '  <applications>' >> /root/.config/openbox/rc.xml \
    && echo '    <application class="*">' >> /root/.config/openbox/rc.xml \
    && echo '      <decor>yes</decor>' >> /root/.config/openbox/rc.xml \
    && echo '    </application>' >> /root/.config/openbox/rc.xml \
    && echo '  </applications>' >> /root/.config/openbox/rc.xml \
    && echo '</openbox_config>' >> /root/.config/openbox/rc.xml

# Configuração do VNC para iniciar com Openbox e Tor Browser
RUN mkdir -p /root/.vnc \
    && echo '#!/bin/sh' > /root/.vnc/xstartup \
    && echo 'xrdb $HOME/.Xresources' >> /root/.vnc/xstartup \
    && echo 'openbox-session &' >> /root/.vnc/xstartup \
    && echo 'tor-browser --no-sandbox &' >> /root/.vnc/xstartup \
    && chmod +x /root/.vnc/xstartup

RUN touch /root/.Xauthority

EXPOSE 5901
EXPOSE 6080

CMD ["bash", "-c", "vncserver -localhost no -SecurityTypes None -geometry 1920x1080 --I-KNOW-THIS-IS-INSECURE && openssl req -new -subj '/C=JP' -x509 -days 365 -nodes -out self.pem -keyout self.pem && websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && tail -f /dev/null"]
