#!/usr/bin/env bash

############################################################################
#
# MODULE:       g.cimis.goes-batch
# AUTHOR(S):    Quinn Hart
# PURPOSE:      Use GOES visible satelitte data to calculate a daily solar insolation
# COPYRIGHT:    (C) 2024 by Quinn Hart
#
#               This program is free software under the GNU General Public
#               License (>=v2). Read the file COPYING that comes with GRASS
#               for details.
#
#############################################################################
# Change to 3 for working
DEBUG=0

#%Module
#%  description: Calculate ETo from GOES 18 satellite data and CIMIS data
#%  keywords: CIMIS evapotranspiration
#%End
#%flag
#% key: b
#% description: Run in Google Batch mode (env vars set)
#% guisection: Main
#%end
#%flag
#% key: f
#% description: force commands to be run regardless if files exist
#% guisection: Main
#%end
#%option
#% key: mapset
#% type: string
#% description: mapset to process
#% required: no
#% guisection: Main
#%end

function G_verify_mapset() {
  local mapset=$1
  if [[ ! ${mapset} =~ ^20[012][0-9][01][0-9][0-3][0-9]$ ]]; then
    g.message -e message="Mapset ${mapset} not valid date format"
    exit 1
  fi
}


## MAIN Program
if  [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program."
    exit 1
fi

# save command line
if [ "$1" != "@ARGS_PARSED@" ] ; then
    exec g.parser "$0" "$@"
fi

# CIMIS uses YYYYMMDD for all standard mapsets
# Global variables
eval $(g.gisenv)
declare -g -A GBL
GBL[GISDBASE]=$GISDBASE
GBL[MAPSET]=$MAPSET
GBL[SAVE_MAPSET]=$MAPSET
GBL[PROJECT]=$LOCATION_NAME
GBL[YYYYMMDD]=${GBL[MAPSET]}
GBL[YYYY]=${MAPSET:0:4}
GBL[MM]=${MAPSET:4:2}
GBL[DD]=${GBL[YYYYMMDD]:6:2}

GBL[tz]=-8
GBL[constant_mapset]=500m


# Get Options
if [ $GIS_FLAG_B -eq 1 ] ; then
  [[ -n ${BATCH_TASK_INDEX} ]] || BATCH_TASK_INDEX=0
   mapset=$(date --date="${MAPSET} +${BATCH_TASK_INDEX} days" +%Y%m%d)
  G_verify_mapset ${mapset}
  GBL[MAPSET]=${mapset}
  g.mapset mapset=${GBL[MAPSET]}
else
  G_verify_mapset ${GBL[MAPSET]}
fi
# Get GOES data from cloud
g.cimis.daily_solar
# Calculate new BVEto
if [[ ${GBL[mapset]} =~ 01$ ]] ; then
  r.eto -f -e
else
  r.eto -f
fi


# Reset to original mapset
g.mapset mapset=${GBL[SAVE_MAPSET]}
exit 0
