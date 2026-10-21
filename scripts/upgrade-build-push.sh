#!/usr/bin/env bash
#
# Upgrade serversideup/php base image, build, and push the Mintage PHP-FPM image.
#
# Usage:
#   ./scripts/upgrade-build-push.sh              # upgrade to latest patch for Dockerfile minor, build, push
#   ./scripts/upgrade-build-push.sh --dry-run    # show planned changes only
#   ./scripts/upgrade-build-push.sh --build-only # upgrade + build, skip push
#   ./scripts/upgrade-build-push.sh --no-upgrade # build/push current Dockerfile base
#   ./scripts/upgrade-build-push.sh 8.4.23       # use a specific patch version
#
# Environment variables (all optional):
#   IMAGE_REGISTRY   Default: registry.gitlab.com/mintage-payroll/mintage
#   IMAGE_TAG_PREFIX Default: PHP-FPM-
#   MINTAGE_TAG      Image tag suffix; default: YYYY.MM.DD-<git-short-sha> (UTC-4, matches mintage CI)
#   BASE_IMAGE_REPO  Default: repository from the Dockerfile FROM line (e.g. serversideup/php)
#   PHP_MINOR        Default: derived from Dockerfile (e.g. 8.5.7 -> 8.5)
#   LOCAL_IMAGE_NAME Default: invernisoft.io/mintage (intermediate build tag, matches mintage CI)
#
# Registry login is not handled here; run `docker login registry.gitlab.com` first.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERFILE="${REPO_ROOT}/Dockerfile"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-registry.gitlab.com/mintage-payroll/mintage}"
IMAGE_TAG_PREFIX="${IMAGE_TAG_PREFIX:-PHP-FPM-}"
BASE_IMAGE_REPO="${BASE_IMAGE_REPO:-}"
PHP_MINOR="${PHP_MINOR:-}"
LOCAL_IMAGE_NAME="${LOCAL_IMAGE_NAME:-invernisoft.io/mintage}"

DRY_RUN=0
BUILD_ONLY=0
NO_UPGRADE=0
REQUESTED_VERSION=""

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage 0 ;;
            -n|--dry-run) DRY_RUN=1; shift ;;
            --build-only) BUILD_ONLY=1; shift ;;
            --no-upgrade) NO_UPGRADE=1; shift ;;
            --version=*) REQUESTED_VERSION="${1#*=}"; shift ;;
            --version) REQUESTED_VERSION="${2:?--version requires a value}"; shift 2 ;;
            -*) die "unknown option: $1 (try --help)" ;;
            *)
                if [[ -z "$REQUESTED_VERSION" ]]; then
                    REQUESTED_VERSION="$1"
                else
                    die "unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done
}

current_base_version() {
    local from_line
    from_line="$(grep -E '^FROM[[:space:]]+' "$DOCKERFILE" | head -1)"
    [[ -n "$from_line" ]] || die "no FROM line found in $DOCKERFILE"
    if [[ "$from_line" =~ ${BASE_IMAGE_REPO}:([0-9]+\.[0-9]+\.[0-9]+)-fpm ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    die "could not parse version from: $from_line"
}

latest_patch_version() {
    local minor="$1"
    python3 - "$minor" "$BASE_IMAGE_REPO" <<'PY'
import json
import re
import sys
import urllib.request

minor = sys.argv[1]
repo = sys.argv[2]
pattern = re.compile(rf"^{re.escape(minor)}\.(\d+)-fpm$")

major_minor = minor.rsplit(".", 1)[0] if "." in minor else minor
tags = []
url = (
    f"https://hub.docker.com/v2/repositories/{repo}/tags"
    f"?page_size=100&name={major_minor}."
)
pages = 0
max_pages = 5
while url and pages < max_pages:
    with urllib.request.urlopen(url, timeout=30) as response:
        data = json.load(response)
    pages += 1
    for tag in data.get("results", []):
        match = pattern.match(tag["name"])
        if match:
            tags.append((int(match.group(1)), tag["name"]))
    url = data.get("next")

if not tags:
    sys.exit(f"no {minor}.*-fpm tags found for {repo}")

best = max(tags)[1]
print(best.replace("-fpm", ""))
PY
}

version_gt() {
    # Returns 0 if $1 > $2 (semver patch compare for X.Y.Z)
    python3 - "$1" "$2" <<'PY'
import sys
a = [int(x) for x in sys.argv[1].split(".")]
b = [int(x) for x in sys.argv[2].split(".")]
print("yes" if a > b else "no")
PY
}

update_dockerfile() {
    local new_version="$1"
    local new_from="FROM ${BASE_IMAGE_REPO}:${new_version}-fpm"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[dry-run] would update Dockerfile: $new_from"
        return 0
    fi
    sed -i "1s|^FROM[[:space:]].*|${new_from}|" "$DOCKERFILE"
    log "updated Dockerfile base image to ${new_version}-fpm"
}

generate_mintage_tag() {
    if [[ -n "${MINTAGE_TAG:-}" ]]; then
        echo "$MINTAGE_TAG"
        return 0
    fi

    local epoch adjusted date_part sha
    epoch="$(date -u +%s)"
    adjusted=$((epoch - 14400))
    if date_part="$(date -u -d "@${adjusted}" +%Y.%m.%d 2>/dev/null)"; then
        :
    else
        date_part="$(date -u -r "${adjusted}" +%Y.%m.%d)"
    fi
    sha="$(git -C "$REPO_ROOT" rev-parse --short=8 HEAD)"
    echo "${date_part}-${sha}"
}

resolve_target_version() {
    local current="$1"

    if [[ -n "$REQUESTED_VERSION" ]]; then
        echo "$REQUESTED_VERSION"
        return 0
    fi

    if [[ "$NO_UPGRADE" -eq 1 ]]; then
        echo "$current"
        return 0
    fi

    latest_patch_version "$PHP_MINOR"
}

main() {
    parse_args "$@"

    [[ -f "$DOCKERFILE" ]] || die "Dockerfile not found at $DOCKERFILE"
    if [[ -z "$BASE_IMAGE_REPO" ]]; then
        BASE_IMAGE_REPO="$(sed -nE 's|^FROM[[:space:]]+([^:[:space:]]+):.*|\1|p' "$DOCKERFILE" | head -1)"
        [[ -n "$BASE_IMAGE_REPO" ]] || die "could not parse base image repository from $DOCKERFILE"
    fi
    command -v docker >/dev/null || die "docker is required"
    command -v python3 >/dev/null || die "python3 is required (used to query Docker Hub tags)"

    local current target new_version
    current="$(current_base_version)"
    if [[ -z "$PHP_MINOR" ]]; then
        PHP_MINOR="$(echo "$current" | cut -d. -f1-2)"
    fi
    target="$(resolve_target_version "$current")"
    new_version="${target}"

    log "current base image: ${BASE_IMAGE_REPO}:${current}-fpm"

    if [[ "$NO_UPGRADE" -eq 0 && -z "$REQUESTED_VERSION" ]]; then
        log "latest ${PHP_MINOR}.*-fpm on Docker Hub: ${target}-fpm"
    elif [[ -n "$REQUESTED_VERSION" ]]; then
        log "requested base image version: ${target}-fpm"
    else
        log "skipping upgrade; using current base image"
    fi

    if [[ "$current" != "$new_version" ]]; then
        update_dockerfile "$new_version"
    else
        log "Dockerfile already at ${new_version}-fpm"
    fi

    local mintage_tag local_tag registry_tag
    mintage_tag="$(generate_mintage_tag)"
    local_tag="${LOCAL_IMAGE_NAME}:${IMAGE_TAG_PREFIX}${mintage_tag}"
    registry_tag="${IMAGE_REGISTRY}:${IMAGE_TAG_PREFIX}${mintage_tag}"

    log "image tags:"
    log "  local:    $local_tag"
    log "  registry: $registry_tag"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "[dry-run] would run: docker build -t $local_tag $REPO_ROOT"
        log "[dry-run] would run: docker tag $local_tag $registry_tag"
        if [[ "$BUILD_ONLY" -eq 0 ]]; then
            log "[dry-run] would run: docker push $registry_tag"
        else
            log "[dry-run] build-only mode: push skipped"
        fi
        exit 0
    fi

    log "building image..."
    docker build -t "$local_tag" "$REPO_ROOT"

    log "tagging for registry..."
    docker tag "$local_tag" "$registry_tag"

    if [[ "$BUILD_ONLY" -eq 1 ]]; then
        log "build-only mode: skipping push"
        log "done. built $registry_tag"
        exit 0
    fi

    log "pushing $registry_tag ..."
    docker push "$registry_tag"
    log "done. pushed $registry_tag"
}

main "$@"
