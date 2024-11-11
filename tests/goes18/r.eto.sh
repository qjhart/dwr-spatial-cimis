#!/usr/bin/env bash

############################################################################
#
# MODULE:       r.eto
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
DEBUG=3

#%Module
#%  description: Calculate ETo from GOES 18 satellite data and CIMIS data
#%  keywords: CIMIS evapotranspiration
#%End
#%flag
#% key: f
#% description: force commands to be run regardless if files exist
#% guisection: Main
#%end
#%flag
#% key: e
#% description: Calculate 28day RMS error
#% guisection: Main
#%end

function G_verify_mapset() {
  if [[ ! ${GBL[YYYYMMDD]} =~ ^20[012][0-9][01][0-9][0-3][0-9]$ ]]; then
    g.message -e message="Mapset ${GBL[YYYYMMDD]} not valid date format"
    exit 1
  fi
}

function Rnl() {
  local Rnl="-(1.35*K-0.35)*(0.34-0.14*sqrt(ea))*4.9e-9*(((Tx+273.16)^4+(Tn+273.16)^4)/2)"
  g.message -d debug=$DEBUG message="Rnl=${Rnl}"
  r.mapcalc ${GBL[overwrite]} --quiet expression="Rnl=${Rnl}"
}

function ETo() {
  local D='(4098.17*0.6108*(exp(Tm*17.27/(Tm+237.3)))/(Tm+237.3)^2)'
  local G="gamma@${GBL[constant_mapset]}"
  local ETo="(900.0*${G}/(Tm+273)*U2*(es-ea)+0.408*${D}*(Rs*(1.0-0.23)+Rnl))/(${D}+${G}*(1.0+0.34*U2))"
  g.message -d debug=$DEBUG message="ETo=${ETo}"

  r.mapcalc ${GBL[overwrite]} --quiet expression="ETo=${ETo}"
	#r.colors --quiet map=ETo rast=ETo@default_colors
}

function rsm() {
  local m=$1
  r.mapcalc --overwrite --quiet expression="${m}_rms=(${m}-${m}_dish)^2";
}

# Get the last 28 days for the matching filename.  We use this to get the
# minimum value from the last 14 days, including the current day.
function rmse28() {
  local B=$1
  local prev=
  local d=0
  local RMSE=${B}_rmse28
	for i in $(seq -27 0); do
	  m=$(date --date="${GBL[YYYYMMDD]} + $i days" +%Y%m%d);
    #g.message -d debug=$DEBUG message="r.info $B@$m"
    if (r.info -r map="${B}_rms@$m" > /dev/null 2>&1); then
      prev+="'${B}_rms@$m'+"
      let d+=1
      #g.message -d debug=$DEBUG message="found $B@$m, prev=$prev"
    fi
  done
  prev=${prev:0:-1}
  local cmd="r.mapcalc  --quiet --overwrite expression=\"${RMSE}=sqrt(($prev)/$d)\""
  g.message -d debug=$DEBUG message="$cmd"
  r.mapcalc  --quiet --overwrite expression="${RMSE}=sqrt(($prev)/$d)"

  echo "'${RMSE}@${GBL[YYYYMMDD]}'"
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
GBL[YYYYMMDD]=${GBL[MAPSET]}
GBL[YYYY]=${MAPSET:0:4}
GBL[MM]=${MAPSET:4:2}
GBL[DD]=${GBL[YYYYMMDD]:6:2}

GBL[tz]=-8
GBL[constant_mapset]=500m

# Get Options
if [ $GIS_FLAG_F -eq 1 ] ; then
  GBL[overwrite]='--overwrite'
else
  GBL[overwrite]=''
fi

G_verify_mapset

g.message -v message="Calculating Rnl / ETo for ${GBL[MAPSET]}"
Rnl
ETo

g.message -v message="Calculating [Rs|K|ETo]_rsm ${GBL[MAPSET]}"
for m in Rs K ETo; do
  rsm $m
done

if [ $GIS_FLAG_E -eq 1 ]; then
  g.message -v message="Calculating [Rs|K|ETo]_rmse28 ${GBL[MAPSET]}"
  for m in Rs K ETo; do
    rmse28 $m
  done
  exit 0
fi
