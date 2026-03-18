#! /usr/bin/make -f
SH:=/bin/bash
GISDBASE:=$(shell g.gisenv get=GISDBASE)
LOCATION:=$(shell g.gisenv get=LOCATION_NAME)
MAPSET:=$(shell g.gisenv get=MAPSET)

dau_vector:=i03_DAU_county_cnty2018

.PHONY: help in_grass vector ${dau_vector} dau

help:  ## Show this help message.
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' ${MAKEFILE_LIST}

in_grass:  ## Check if we are in a GRASS GIS session
	@if  [ -z "$${GISBASE}" ] ; then \
    echo "You must be in GRASS GIS to run this program."; \
    exit 1; \
	fi

dau:${GISDBASE}/cimis/500m/cellhd/dau ## Generate the dau@500m raster layer.

dau_vector: ${dau_vector} ## Generate the DAU vector layer i03_DUA_county_cnty2018@PERMANENT
${dau_vector}:${GISDBASE}/cimis/PERMANENT/vector/${dau_vector}

${GISDBASE}/cimis/PERMANENT/vector/${dau_vector}:in_grass
	d=$$(mktemp -d); echo $$d; \
	curl --follow 'https://gis.data.cnra.ca.gov/api/download/v1/items/27dbe3d6fb4e4bd5921e27313e406397/shapefile?layers=0' --output=$$d/${dau_vector}.zip; \
	unzip -o $$d/${dau_vector}.zip -d $$d; \
	g.mapset mapset=PERMANENT; \
	v.import input=$$d/${dau_vector}.shp output=${dau_vector} --overwrite; \
	v.db.update map=${dau_vector} column=DAU_NAME value="West Marin" where='DAU_CODE="038"'; \
	v.db.addcolumn map=${dau_vector} column="dau integer"; \
	v.db.update map=${dau_vector} column=dau qcol="CAST(DAU_CODE AS integer)"; \
	g.mapset mapset=${MAPSET}; \
	rm -rf $$d

${GISDBASE}/cimis/500m/cellhd/dau: in_grass ${GISDBASE}/cimis/PERMANENT/vector/${dau_vector}
	g.mapset mapset=500m; \
	g.region rast=state@500m; \
	v.to.rast --overwrite input=${dau_vector}@PERMANENT output=dau attribute_column=dau label_column=DAU_NAME use=attr ; \
	g.mapset mapset=${MAPSET}
