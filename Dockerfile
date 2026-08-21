FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y && apt install --no-install-recommends -y xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify sudo xterm init systemd snapd vim net-tools curl wget git tzdata
RUN apt update -y && apt install -y dbus-x11 x11-utils x11-xserver-utils x11-apps
RUN apt install software-properties-common -y

# MUDANÇA 1: Removido Firefox e adicionado Thorium
RUN wget -qO - https://dl.thorium.rocks/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.thorium.rocks/debian/ stable main" >> /etc/apt/sources.list.d/thorium.list \
    && apt update -y \
    && apt install -y thorium-browser \
    && apt clean

RUN apt update -y && apt install -y xubuntu-icon-theme
RUN touch /root/.Xauthority
EXPOSE 5901
EXPOSE 6080

# MUDANÇA 2: Adicionado thorium-browser para iniciar junto com o VNC
CMD bash -c "vncserver -localhost no -SecurityTypes None -geometry 1920x1080  --I-KNOW-THIS-IS-INSECURE && thorium-browser --no-sandbox --disable-dev-shm-usage & openssl req -new -subj '/C=JP' -x509 -days 365 -nodes -out self.pem -keyout self.pem && websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901 && tail -f /dev/null"
