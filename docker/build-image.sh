#!/bin/bash

set -eux

if [[ ${REPO_OWNER} != "alphagov" ]]; then
  echo "Not alphagov so no need to build images PRs"
  exit 0
fi

build () {
  if [ "${ARCH}" = "amd64" ]; then
    docker build . -t "ghcr.io/alphagov/${APP}:${1}" -f "docker/${APP}/${2}.Dockerfile"
  else
    docker buildx build --platform "linux/${ARCH}" . -t "ghcr.io/alphagov/${APP}:${1}" -f "docker/${APP}/${2}.Dockerfile"
  fi
}

if [[ -n ${SKIP:-} ]]; then
  exit
fi

if [[ ${BUILD_BASE:-} = "true" ]]; then
  if [ "${APP}" = "ckan" ]; then
    if [[ -n ${PATCH:-} ]]; then
      build "${VERSION}-${PATCH}-core" "${VERSION}-core"
      build "${VERSION}-${PATCH}-base" "${VERSION}-base"
    else
      build "${VERSION}-core" "${VERSION}-core"
      build "${VERSION}-base" "${VERSION}-base"
    fi
  else
    DOCKER_TAG="${VERSION}"
  fi
else
  if [[ -n ${GH_REF:-} ]]; then  
    DOCKER_TAG="${GH_REF}"
  else
    DOCKER_TAG="${GITHUB_SHA}"
  fi
fi

if [[ -n ${DOCKER_TAG:-} ]]; then
  if [[ -n ${PATCH:-} ]]; then
    build "${DOCKER_TAG}-${PATCH}" "${VERSION}"
  else
    build "${DOCKER_TAG}" "${VERSION}"
  fi
fi

if [[ -n ${DRY_RUN:-} ]]; then
  echo "Dry run; not pushing to registry"
else
  if [[ -n ${DOCKER_TAG:-} ]]; then
    if [[ -n ${PATCH:-} ]]; then
      docker push "ghcr.io/alphagov/${APP}:${DOCKER_TAG}-${PATCH}"
    else
      docker push "ghcr.io/alphagov/${APP}:${DOCKER_TAG}"
    fi
  else
    if [[ -n ${PATCH:-} ]]; then
      docker push "ghcr.io/alphagov/${APP}:${VERSION}-${PATCH}-core"
      docker push "ghcr.io/alphagov/${APP}:${VERSION}-${PATCH}-base"
    else
      docker push "ghcr.io/alphagov/${APP}:${VERSION}-core"
      docker push "ghcr.io/alphagov/${APP}:${VERSION}-base"
    fi

    # tags only used for test images
    if [[ -n ${TAG:-} ]]; then
      build "${TAG}" "${VERSION}"
      docker push "ghcr.io/alphagov/${APP}:${TAG}"
    fi

  fi
fi
