registry := "ghcr.io/thrix"
image_tag := env("IMAGE_TAG", "latest")
image_name := "workstation"
image := registry + "/" + image_name + ":" + image_tag

push_username := "thrix"
push_password := env("PUSH_PASSWORD")
vault_password := env("VAULT_PASSWORD")

_default:
    @just --list --list-heading $'Available commands:\n'

all: decrypt build test login push

# Decrypt secret files
decrypt:
    @for file in $(find . -name *.encrypted); do \
      echo "Decrypting file '$file' ..."; \
      ansible-vault decrypt --output ${file%.encrypted} $file; \
    done
    chmod 644 files/system/etc/pki/ca-trust/source/anchors/Current-IT-Root-CAs.pem

# Build container image
build:
    bluebuild build --registry {{ registry }}

# Build container image from Containerfile
build-containerfile:
    buildah build -t {{ image }}

# Run building via tmt
build-tmt:
    tmt run -vvv -e VAULT_PASSWORD={{ vault_password }} -e PUSH_PASSWORD={{ push_password }} plan --name /ci/build

# Run building via tmt
pre-commit-tmt:
    tmt run -vvv -e VAULT_PASSWORD={{ vault_password }} -e PUSH_PASSWORD={{ push_password }} plan --name /ci/pre-commit

# Generate Containerfile
generate:
    bluebuild generate | grep -Ev "(org\.blue-build\.build-id|org\.opencontainers\.image\.created)" > Containerfile

# Push image to registry
push:
    buildah push {{ image }}

# Login to the container registry
login:
    @echo "As '{{ push_username }}' to '{{ registry }}'"
    @buildah login -u "{{ push_username }}" -p "{{ push_password }}" "{{ registry }}"

# Run goss tests
test:
    dgoss run --stop-timeout=0 --entrypoint sleep {{ image }} infinity

# Run goss tests
test-edit:
    dgoss edit --stop-timeout=0 --entrypoint sleep {{ image }} infinity
