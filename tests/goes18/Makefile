#! /usr/bin/make -f
SH:=/bin/bash

GCLOUD:=us-west1-docker.pkg.dev/dwr-spatial-cimis/docker
LOCAL:=localhost/dwr-spatial-cimis

NAME:=goes18
TAG:=$(shell git describe --always --dirty | sed -e 's/^.*-dirty$$/dirty/')

INFO:

build:
	DOCKER_BUILDKIT=1 docker build --build-arg BUILDKIT_INLINE_CACHE=1 -t ${LOCAL}/${NAME}:${TAG} --cache-from ${LOCAL}/${NAME}:dirty .

push:
	docker tag ${LOCAL}/${NAME}:${TAG} ${GCLOUD}/${NAME}:${TAG}
	docker push ${GCLOUD}/${NAME}:${TAG}

run:
	docker run --rm -e LOCAL_USER_ID=$(id --user) -v ./gdb:/grassdb localhost/dwr-spatial-cimis/goes18:dirty
