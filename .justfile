registry := "ghcr.io"
image_tag := "latest"
image := registry + "/thrix/workstation:" + image_tag
push_username := "thrix"
push_password := env("PUSH_PASSWORD", "unknown")

_default:
    @just --list --list-heading $'Available commands:\n'

all: decrypt build test login push

# Decrypt secret files
decrypt:
    @for file in $(find . -name *.encrypted); do \
      echo "Decrypting file '$file' ..."; \
      ansible-vault decrypt --output ${file%.encrypted} $file; \
      chmod 644 ${file%.encrypted}; \
    done

# Build container image
build:
    @podman build --pull=always -t {{ image }} .

# Push image to registry
push:
    podman push {{ image }}

# Login to the container registry
login:
    @echo "As '{{ push_username }}' to '{{ registry }}'"
    @podman login -u "{{ push_username }}" -p "{{ push_password }}" "{{ registry }}"

# Run goss tests
test:
    dgoss run --stop-timeout=0 --entrypoint sleep {{ image }} infinity
