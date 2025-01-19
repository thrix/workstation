# Build from Universal Blue images, until Fedora provides them
# https://github.com/ublue-os/main/pkgs/container/sericea-main
# FROM ghcr.io/ublue-os/sericea-main:latest
FROM alpine

LABEL org.opencontainers.image.source=https://github.com/thrix/workstation
LABEL org.opencontainers.image.description="Workstation based on Universal Blue Sericea"
LABEL org.opencontainers.image.licenses=MIT

# Copy system files
COPY etc /etc
COPY usr /usr

RUN <<EOF
# Use strict mode
set -euxo pipefail

# Install Xerox 3020 legacy drivers
# Installing to /opt does not work, see https://containers.github.io/bootc/filesystem.html#opt
# Because /opt is a symlink to /var/opt, move the installed /opt content to /var/opt
mv /opt /opt-backup
dnf -y install https://gitlab.com/mvadkert/xerox-3020/-/raw/main/xerox-3020-1.0.0-1.x86_64.rpm
mv /opt /var
mv /opt-backup /opt

# Install additional packages
dnf -y install fontawesome-fonts-all mate-polkit nautilus

# Update CA certificates
update-ca-trust

# https://coreos.github.io/rpm-ostree/container/#using-ostree-container-commit
ostree container commit
EOF
