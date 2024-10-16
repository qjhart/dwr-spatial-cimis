ARG GRASS_TAG=releasebranch_8_4-debian
ARG R_IHELIOSAT_VERSION=1.2.0
ARG G_CIMIS_DAILY_SOLAR_VERSION=1.0.0
ARG ARC=https://github.com/qjhart

FROM osgeo/grass-gis:${GRASS_TAG} as grass

RUN [[ -d /usr/local/grass83/raster ]] || mkdir /usr/local/grass83/raster && \
    cd /usr/local/grass83/raster && \
    curl ${ARC}/r.iheliosat/archive/refs/tags/${R_IHELIOSAT_VERSION}.tar.gz | tar -xzf - && \
    cd r.iheliosat-${R_IHELIOSAT_VERSION} && make
#    rm /usr/local/grass83/raster/r.iheliosat-${R_IHELIOSAT_VERSION}

RUN [[ -d /usr/local/grass83/general ]] || mkdir /usr/local/grass83/general && \
    cd /usr/local/grass83/raster && \
    curl ${ARC}/g.cimis.daily_solar/archive/refs/tags/${G_CIMIS_DAILY_SOLAR_VERSION}.tar.gz | tar -xzf - && \
    cd g.cimis.daily_solar-${G_CIMIS_DAILY_SOLAR_VERSION} && make

WORKDIR /grassdb

#RUN rm -rf /usr/local/grass83/raster
