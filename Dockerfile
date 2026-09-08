FROM debian:12-slim

RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    nano \
    vim \
    htop \
    net-tools \
    iproute2 \
    ca-certificates \
    cron \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /etc/ssh
RUN echo "PermitRootLogin no" >> /etc/ssh/sshd_config
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
RUN echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
RUN echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

RUN ssh-keygen -A

COPY motd.sh /etc/update-motd.d/00-quantum
RUN chmod +x /etc/update-motd.d/00-quantum
RUN /etc/update-motd.d/00-quantum > /etc/motd || true

COPY quantum-prompt.sh /etc/profile.d/quantum-prompt.sh
RUN chmod +x /etc/profile.d/quantum-prompt.sh

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
