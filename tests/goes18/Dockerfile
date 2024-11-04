ARG GRASS_TAG=releasebranch_8_4-debian

#FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:stable as gustil

FROM osgeo/grass-gis:${GRASS_TAG} as grass
ARG R_IHELIOSAT_VERSION=1.2.0
ARG G_CIMIS_DAILY_SOLAR_VERSION=2.0.1
ARG ARC=https://github.com/qjhart

RUN apt update && apt install -y \
    vim apt-transport-https ca-certificates \
    lsb-release git gnupg curl python3

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt-get update && apt-get install -y google-cloud-cli google-cloud-sdk-gke-gcloud-auth-plugin

RUN [[ -d /usr/local/grass/raster ]] || mkdir -p /usr/local/grass/raster && \
    cd /usr/local/grass/raster && \
    curl -L ${ARC}/r.iheliosat/archive/refs/tags/${R_IHELIOSAT_VERSION}.tar.gz | tar -xzf - && \
    cd r.iheliosat-${R_IHELIOSAT_VERSION} && make && \
    rm -rf /usr/local/grass/raster/r.iheliosat-${R_IHELIOSAT_VERSION}

RUN [[ -d /usr/local/grass/general ]] || mkdir -p /usr/local/grass/general && \
    cd /usr/local/grass/general && \
    curl -L ${ARC}/g.cimis.daily_solar/archive/refs/tags/${G_CIMIS_DAILY_SOLAR_VERSION}.tar.gz | tar -xzf - && \
    cd g.cimis.daily_solar-${G_CIMIS_DAILY_SOLAR_VERSION} && make && \
    rm -rf /usr/local/grass/general/g.cimis.daily_solar-${G_CIMIS_DAILY_SOLAR_VERSION}

COPY r.eto.sh /usr/local/grass/bin/r.eto
COPY g.cimis.goes-batch.sh /usr/local/grass/bin/g.cimis.goes-batch
COPY run.sh /

WORKDIR /grassdb
ENV GISDBASE=/grassdb
ENV PROJECT=cimis
ENV MAPSET=PERMANENT

VOLUME /var/tmp
VOLUME /grassdb


ENTRYPOINT ["/run.sh"]
#ENTRYPOINT ["sh","-c","grass --text -c EPSG:3310 ${GISDBASE}/${PROJECT}/${MAPSET} --exec $@"]
CMD ["g.cimis.goes-batch","--verbose","-b"]
