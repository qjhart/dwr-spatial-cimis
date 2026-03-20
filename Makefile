#! /usr/bin/make -f
SH:=/bin/bash
GISDBASE:=$(shell g.gisenv get=GISDBASE)
LOCATION:=$(shell g.gisenv get=LOCATION_NAME)
MAPSET:=$(shell g.gisenv get=MAPSET)

dau_cnty:=i03_DAU_county_cnty2018

.PHONY: help in_grass vector ${dau_cnty} dau

help:  ## Show this help message.
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' ${MAKEFILE_LIST}

in_grass:  ## Check if we are in a GRASS GIS session
	@if  [ -z "$${GISBASE}" ] ; then \
    echo "You must be in GRASS GIS to run this program."; \
    exit 1; \
	fi

dau:${GISDBASE}/cimis/PERMANENT/vector/dau ## Generate the dau@500m raster layer.

dau_cnty: ${dau_cnty} ## Generate the DAU vector layer i03_DUA_county_cnty2018@PERMANENT

${dau_cnty}:${GISDBASE}/cimis/PERMANENT/vector/${dau_cnty} in_grass

# I have to add a snap, because the shapfile has some overlapping polygons.
${GISDBASE}/cimis/PERMANENT/vector/${dau_cnty}:
	d=$$(mktemp -d); echo $$d; \
	curl --follow 'https://gis.data.cnra.ca.gov/api/download/v1/items/27dbe3d6fb4e4bd5921e27313e406397/shapefile?layers=0' --output=$$d/${dau_cnty}.zip; \
	unzip -o $$d/${dau_cnty}.zip -d $$d; \
	g.mapset mapset=PERMANENT; \
	v.import input=$$d/${dau_cnty}.shp output=${dau_cnty} snap=1 --overwrite; \
	v.edit map=${dau_cnty} tool=delete where="TYPE='Water'"; \
	v.db.update map=${dau_cnty} column=DAU_NAME value="West Marin" where='DAU_CODE="038"'; \
	v.db.addcolumn map=${dau_cnty} column="dau integer"; \
	v.db.update map=${dau_cnty} column=dau qcol="CAST(DAU_CODE AS integer)"; \
	g.mapset mapset=${MAPSET}; \
	rm -rf $$d

${GISDBASE}/cimis/PERMANENT/vector/dau:${GISDBASE}/cimis/PERMANENT/vector/${dau_cnty}
	v.dissolve input=${dau_cnty} layer=1 output=dau column=DAU_CODE --overwrite
	v.edit tool=delete map=dau where="DAU_CODE=''"
	v.to.db map=dau option=area columns=hectares units=kilometers --overwrite

# ${GISDBASE}/cimis/500m/cellhd/dau:${GISDBASE}/cimis/PERMANENT/vector/${dau_cnty}
# 	g.mapset mapset=500m; \
# 	g.region rast=state@500m; \
# 	v.to.rast --overwrite input=dau@PERMANENT output=dau attribute_column=DAU_CODE label_column=DAU_NAME use=attr ; \
# 	g.mapset mapset=${MAPSET}
