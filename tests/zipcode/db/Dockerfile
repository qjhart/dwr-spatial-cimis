FROM postgres:16-bookworm
MAINTAINER Quinn Hart <qjhart@ucdavis.edu>

RUN apt-get update \
	&& apt-get install -y build-essential git-core \
	postgresql-server-dev-$PG_MAJOR \
  curl less \
#  libv8-dev postgresql-$PG_MAJOR-plv8 \
  && rm -rf /var/lib/apt/lists/*

# Put at end to stop remaking everytime :)
COPY initdb.d/ /docker-entrypoint-initdb.d/
