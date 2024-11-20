#!/usr/bin/env bash

############################################################################
#
# MODULE:       g.cimis.daily_solar
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
#%  description: Runs standard Spatial CIMIS Daily Insolation Calculations
#%  keywords: CIMIS evapotranspiration
#%End
#%flag
#% key: s
#% description: skip B2 image check
#% guisection: Main
#%end
#%option
#% key: interval
#% type: integer
#% description: GOES 18 image interval in minutes (if fetching), default 20
#% required: no
#% guisection: Main
#% key: mapset
#% type: string
#% description: mapset to process
#% required: no
#% guisection: Main
#%end

function G_verify_mapset() {
  if [[ ! ${GBL[YYYYMMDD]} =~ ^20[012][0-9][01][0-9][0-3][0-9]$ ]]; then
    g.message -e "Mapset ${GBL[YYYYMMDD]} not valid date format"
    exit 1
  fi
}


function get_image_interval_list() {
  local interval=${GBL[interval]}
  local SUNRISE=${GBL[SUNRISE]}
  local SUNSET=${GBL[SUNSET]}
  local from=$(( $SUNRISE / $interval * $interval ))
  # For GOES 18, intervals start at the 1 minute mark
  from=$(( $from + 1 ))
  local list=
  while true; do
    local h m
    h=$(printf "%02d" $(( $from / 60 )))
    m=$(printf "%02d" $(( $from % 60 )))
    list+="$h${m}PST-B2 "
    if [[ $from -gt $SUNSET ]]; then
      break
    fi
    from=$(( $from + $interval ))
  done
  echo ${list:0:-1}
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
eval "$(g.gisenv)"
declare -g -A GBL
GBL[GISDBASE]=$GISDBASE
GBL[MAPSET]=$MAPSET
GBL[PROJECT]=$LOCATION_NAME
GBL[YYYYMMDD]=${GBL[MAPSET]}
GBL[YYYY]=${MAPSET:0:4}
GBL[MM]=${MAPSET:4:2}
GBL[DD]=${GBL[YYYYMMDD]:6:2}

GBL[tz]=-8
GBL[elevation]=Z@500m
GBL[interval]=20
GBL[tmpdir]=/var/tmp/cimis
GBL[DOY]=$(date --date="${GBL[YYYY]}-${GBL[MM]}-${GBL[DD]}" +%j)
GBL[s3_bucket]='s3://noaa-goes18/ABI-L1b-RadC'
GBL[gs_bucket]='gs://gcp-public-data-goes-18/ABI-L1b-RadC'
GBL[pattern]='[012][0-9][0-5][0-9]PST-B2'

GBL[mask]="state@500m"
GBL[mask_cnt]=1642286
GBL[v_mask_cnt]=1641112

# Verify the mask
function verify_mask() {
  local mask_cnt
  mask_cnt=$(r.stats --quiet -n -c state@500m  | cut -d' ' -f2)
  if (( $mask_cnt != ${GBL[mask_cnt]} )); then
    g.message -e "Mask count (${GBL[mask_cnt]})=$mask_cnt, expected ${GBL[mask_cnt]}.  You may have another mask in place."
    exit 1
  fi
}

# Get Options
if [ $GIS_FLAG_S -eq 1 ] ; then
  GBL[skip_count_valid_pixels]=true
else
  GBL[skip_count_valid_pixels]=false
fi


verify_mask
G_verify_mapset

GBL[SUNRISE]=$(g.gisenv get=SUNRISE store=mapset)
GBL[SUNSET]=$(g.gisenv get=SUNSET store=mapset)

# if either sunrise or sunset are not set, exit with error
if [[ -z ${GBL[SUNRISE]} || -z ${GBL[SUNSET]} ]]; then
  g.message -e "Sunrise or Sunset not set"
  exit 1
fi

function count_valid_pixels() {
  local B=$1
  local total_cnt=$2 || ${GBL[mask_cnt]}
  local tmp='XX'
  if [[ ${GBL[SKIP]} == 'true' ]]; then
    echo $total_cnt
    return
  fi
  r.mapcalc --quiet --overwrite expression="$tmp=not(isnull('$B')) && '${GBL[mask]}'";
  valid_cnt=$(r.stats --quiet -c $tmp | grep '^1 ' | cut -d' ' -f2)
  if [[ -z $valid_cnt ]]; then
    valid_cnt=0
  fi
  g.remove --quiet -f type=rast name=$tmp
  if (( valid_cnt < total_cnt )); then
    g.message -w "$B has nulls (( ${valid_cnt} < $total_cnt ))"
  fi
  echo $valid_cnt
}

function test_solar() {
  local list B r v
  declare -A S=(
    [B]=0 [B_missing]=0 [B_err]=0
  )
  S[mapset]=$MAPSET
  list=$(get_image_interval_list)
  g.message -v message="List: $list"
  for B in $list; do
    if  r=$(r.info -r $B 2>/dev/null); then

      v=$(count_valid_pixels $B);
      if (( v < GBL[mask_cnt] )) ; then
        (( S[B_err]++ ))
      else
        (( S[B]++ ))
      fi
    else
       (( S[B_missing]++ ))
    fi
  done
  local json="{\"mapset\":\"$MAPSET\","
  json+="\"B\":{\"cnt\":$(( S[B] )),\"missing\":$(( S[B_missing] )),\"err\":$(( S[B_err] ))},"
  for B in ETo_rms ETo Rs; do
    if r=$(r.info -r $B 2>/dev/null); then
      json+="\"$B\":{"
      eval "$r"
      json+="\"max\":$max,\"min\":$min"
      if [[ ${GBL[skip_count_valid_pixels]} == 'true' ]]; then
        v=$(count_valid_pixels $B);
        if (( v < GBL[v_mask_cnt] )); then
          echo $B $r $v;
          json+=",\"mask\":$v"
        fi
      fi
      json+="},"
    fi
  done
  echo ${json:0:-1}'}'
}

test_solar
