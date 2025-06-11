# This stage is responsible for holding onto
# your config without copying it directly into
# the final image
FROM scratch AS stage-files
COPY ./files /files


# Copy modules
# The default modules are inside blue-build/modules
# Custom modules overwrite defaults
FROM scratch AS stage-modules
COPY ./modules /modules

# Bins to install
# These are basic tools that are added to all images.
# Generally used for the build process. We use a multi
# stage process so that adding the bins into the image
# can be added to the ostree commits.
FROM scratch AS stage-bins
COPY --from=ghcr.io/sigstore/cosign/cosign:v2.5.0 /ko-app/cosign /bins/cosign
COPY --from=ghcr.io/blue-build/cli:latest-installer \
  /out/bluebuild /bins/bluebuild
# Keys for pre-verified images
# Used to copy the keys into the final image
# and perform an ostree commit.
#
# Currently only holds the current image's
# public key.
FROM scratch AS stage-keys
COPY cosign.pub /keys/workstation.pub


# Main image
FROM ghcr.io/ublue-os/sway-atomic-main@sha256:83ba21ffac3f90c5299d8fa7c23cbac80f0fe581e99554b18c8e91ea8ab4a98a AS workstation
ARG RECIPE=./recipes/recipe.yml
ARG IMAGE_REGISTRY=localhost
ARG CONFIG_DIRECTORY="/tmp/files"
ARG MODULE_DIRECTORY="/tmp/modules"
ARG IMAGE_NAME="workstation"
ARG BASE_IMAGE="ghcr.io/ublue-os/sway-atomic-main"
# Key RUN
RUN --mount=type=bind,from=stage-keys,src=/keys,dst=/tmp/keys \
  mkdir -p /etc/pki/containers/ \
  && cp /tmp/keys/* /etc/pki/containers/

# Bin RUN
RUN --mount=type=bind,from=stage-bins,src=/bins,dst=/tmp/bins \
  mkdir -p /usr/bin/ \
  && cp /tmp/bins/* /usr/bin/
RUN --mount=type=bind,from=ghcr.io/blue-build/nushell-image:default,src=/nu,dst=/tmp/nu \
  mkdir -p /usr/libexec/bluebuild/nu \
  && cp -r /tmp/nu/* /usr/libexec/bluebuild/nu/
RUN --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/scripts/ \
  /scripts/pre_build.sh

# Module RUNs
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/rpm-ostree:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-workstation-latest,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-workstation-latest,sharing=locked \
  /tmp/scripts/run_module.sh 'rpm-ostree' '{"type":"rpm-ostree","install":["fontawesome-fonts-all","mate-polkit","nautilus","https://gitlab.com/mvadkert/xerox-3020/-/raw/main/xerox-3020-1.0.0-1.x86_64.rpm","https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"],"optfix":["google","smfp-common"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/bling:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-workstation-latest,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-workstation-latest,sharing=locked \
  /tmp/scripts/run_module.sh 'bling' '{"type":"bling","install":["rpmfusion"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/files:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-workstation-latest,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-workstation-latest,sharing=locked \
  /tmp/scripts/run_module.sh 'files' '{"type":"files","files":[{"source":"system","destination":"/"}]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/fonts:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-workstation-latest,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-workstation-latest,sharing=locked \
  /tmp/scripts/run_module.sh 'fonts' '{"type":"fonts","fonts":{"google-fonts":["Source Code Pro"],"nerd-fonts":["FiraCode","Iosevka","JetBrainsMono"]}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/script:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-workstation-latest,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-workstation-latest,sharing=locked \
  /tmp/scripts/run_module.sh 'script' '{"type":"script","snippets":["update-ca-trust","rm -f /usr/share/wireplumber/scripts/node/suspend-node.lua","ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/systemd:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-workstation-latest,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-workstation-latest,sharing=locked \
  /tmp/scripts/run_module.sh 'systemd' '{"type":"systemd","system":{"enabled":["systemd-timesyncd"]}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/default-flatpaks:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-workstation-latest,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-workstation-latest,sharing=locked \
  /tmp/scripts/run_module.sh 'default-flatpaks' '{"type":"default-flatpaks","notify":true,"system":{"install":["com.dropbox.Client","com.tomjwatson.Emote","com.transmissionbt.Transmission","com.yubico.yubioath","im.riot.Riot","io.podman_desktop.PodmanDesktop","org.fedoraproject.MediaWriter","org.flameshot.Flameshot","org.gimp.GIMP","org.libreoffice.LibreOffice","org.videolan.VLC"]}}'

RUN --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:7828e7872b342d05302417db1bd94bf93d347383,src=/scripts/,dst=/scripts/ \
  /scripts/post_build.sh

# Labels are added last since they cause cache misses with buildah
LABEL org.opencontainers.image.title="workstation"
LABEL org.opencontainers.image.description="Thrix's workstation"
LABEL org.opencontainers.image.source=""
LABEL org.opencontainers.image.base.digest="sha256:83ba21ffac3f90c5299d8fa7c23cbac80f0fe581e99554b18c8e91ea8ab4a98a"
LABEL org.opencontainers.image.base.name="ghcr.io/ublue-os/sway-atomic-main:latest"
LABEL io.artifacthub.package.readme-url=https://raw.githubusercontent.com/blue-build/cli/main/README.md
