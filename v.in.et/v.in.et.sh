#!/usr/bin/env bash

############################################################################
#
# MODULE:       v.in.et
# AUTHOR(S):    Quinn Hart
# PURPOSE:      Retrieve CIMIS data from et.water.ca.gov and create a GRASS vector
# COPYRIGHT:    (C) 2003-2026 by Quinn Hart
#
#               This program is free software under the GNU General Public
#               License (>=v2). Read the file COPYING that comes with GRASS
#               for details.
#
#############################################################################
# Change to 3 for working
DEBUG=3
#%Module
#%  description: Get Daily Vector from et.water.ca.gov using JSON services
#%  keywords: CIMIS evapotranspiration
#%End
#%flag
#% key: overwrite
#% description: Overwrite
#%end
#%flag
#% key: verbose
#% description: Verbose Reporting
#%end
#%option
#% key: api
#% type: string
#% description: URL of water API
#% answer: https://et.water.ca.gov/api
#% required : no
#%end
#%option
#% key: items
#% type: string
#% description: Variables to include
#% multiple: yes
#% answer: day-asce-eto,day-precip,day-sol-rad-avg,day-vap-pres-avg,day-air-tmp-max,day-air-tmp-min,day-air-tmp-avg,day-rel-hum-max,day-rel-hum-min,day-rel-hum-avg,day-dew-pnt,day-wind-spd-avg
#% required : no
#%end
#%option
#% key: stations
#% type: string
#% description: Stations to include
#% multiple: yes
#% required : no
#%end
#%option
#% key: appkey
#% type: string
#% description: ET Application Key.  If not specified look in g.gisenv ET_APPKEY
#% multiple: no
#% required : no
#%end

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
GBL[YYYYMMDD]=${MAPSET%[_-]*}
GBL[PROJECT]=$LOCATION_NAME
GBL[tz]=-8
GBL[elevation]=Z@500m
#GBL[mktemp_template]=/var/tmp/cimisXXXX
GBL[tmpdir]=$GISDBASE/$LOCATION_NAME/$MAPSET/etc
GBL[mask]="state@500m"
GBL[mask_cnt]=1642286
# Spline parameters for normalizing station data
# Lapse Rates/Tensions/Smooth for dewp and min_at
GBL[T_tension]=10
GBL[T_smooth]=0.03
GBL[lr-day_dew_pnt]=5
GBL[lr-day_air_tmp_min]=5
GBL[lr-day_air_tmp_max]=5

# DEFAULTS
GBL[appkey]=$ET_APPKEY;

GBL[api]=$GIS_OPT_API;

if [ $GIS_FLAG_O -eq 1 ] ; then
  GBL[overwrite]=true
else
  GBL[overwrite]=false
fi

GBL[items]="$GIS_OPT_ITEMS"

if [[ -n $GIS_OPT_APPKEY && ( "$GIS_OPT_APPKEY" != "" ) ]] ; then
  echo "HAVE KEY";
  GBL[appkey]=$GIS_OPT_APPKEY
fi

GBL[YYYY]=${GBL[YYYYMMDD]:0:4};
GBL[MM]=${GBL[YYYYMMDD]:4:2};
GBL[DD]=${GBL[YYYYMMDD]:6:2};
GBL[YYYY-MM-DD]="${GBL[YYYY]}-${GBL[MM]}-${GBL[DD]}"
GBL[DOY]=$(date --date="${GBL[YYYY]}-${GBL[MM]}-${GBL[DD]}" +%j);

#declare -p GBL

function G_verify_mapset() {
  if [[ ! ${GBL[YYYYMMDD]} =~ ^20[012][0-9][01][0-9][0-3][0-9] ]]; then
    g.message -e "Mapset ${GBL[YYYYMMDD]} not valid date format"
    exit 1
  fi
}

function station() {
  # Get a tmpdir
  local d
  local vrt
  #d=$(mktemp -d ${GBL[mktemp_template]})
  #GBL[tmpdir]=$d
  d=${GBL[tmpdir]}

  if $( `${GBL[overwrite]}` ); then
    for m in station; do
      if (v.info -t $m > /dev/null 2>&1 ); then
        g.message -v message="vector $m exists, deleting"
        g.remove -f type=vect pattern=$m
      fi
    done
  fi

  if (v.info -t station > /dev/null 2>&1 ); then
    g.message -v message='vector station exists'
  else
    [[ -d $d ]] || mkdir $d;
    if [[ -f $d/station.json ]]; then
      g.message -v message="$d/station.json exists"
    else
      g.message -v message="curl ${GBL[api]}/station?appKey=${GBL[appkey]} > $d/station.json"
      curl ${GBL[api]}/station?appKey=${GBL[appkey]} > $d/station.json
    fi;
    if [[ -f $d/station.csv ]]; then
      g.message -v message="$d/station.csv exists"
    else
      g.message -d debug=1 message="jq";
      jq -r '["StationNbr","Name","City","RegionalOffice","Count","ConnectDate","DisconnectDate","IsActive","IsEtoStation","Elevation","z","GroundCover","latitude","longitude"],(.Stations.[] | select(.IsActive=="True") | [(.StationNbr | tonumber),.Name,.City,.RegionalOffice,.County,.ConnectDate,.DisconnectDate,.IsActive,.IsEtoStation,(.Elevation | tonumber),(.Elevation | tonumber)*0.3048,.GroundCover,(.HmsLatitude | split(" / ")[1]),(.HmsLongitude | split(" / "))[1]]) | @csv' $d/station.json > $d/station.csv
  fi;

    if [[ -f $d/station.vrt ]]; then
      g.message -v message="$d/station.vrt exists"
    else
      cat <<EOF > $d/station.vrt
<OGRVRTDataSource>
    <OGRVRTLayer name="station">
        <SrcDataSource>station.csv</SrcDataSource>
        <GeometryType>wkbPoint</GeometryType>
        <LayerSRS>WGS84</LayerSRS>
        <GeometryField encoding="PointFromColumns" x="longitude" y="latitude" z="z"/>
        <Field name="StationNbr"  type="integer" />
        <Field name="Name" type="string" />
        <Field name="City" type="string" />
        <Field name="RegionalOffice" type="string" />
        <Field name="County" type="string" />
        <Field name="ConnectDate" type="date" />
        <Field name="DisconnectDate" type="date" />
        <Field name="isActive" type="string" />
        <Field name="isEtoStation" type="string" />
        <Field name="Elevation" type="real" />
        <Field name="GroundCover" type="string" />
    </OGRVRTLayer>
</OGRVRTDataSource>
EOF
    fi

    # Make a temporary project for thie import
    local tmpproj
    tmpproj=$(mktemp -u ${GBL[GISDBASE]}/tmpXXXX)
    # finally make vector
    g.message -v message="v.in.ogr input=station.vrt output=station project=$tmpproj key=StationNbr"
    (cd $d; v.in.ogr input=station.vrt output=station project=$(basename $tmpproj) key=StationNbr)
    v.proj project=$(basename $tmpproj) input=station mapset=PERMANENT output=station
    rm -rf $tmpproj
  fi
}

function data() {
  local d
  d=${GBL[tmpdir]}

  if ( `${GBL[overwrite]}` ) ; then
    for m in et z_normal data; do
      if (v.info -t $m > /dev/null 2>&1 ); then
        g.message -v message="vector $m exists, deleting"
        g.remove -f type=vect pattern=$m
      fi
    done
    for m in data; do
      if (db.describe -c table=$m > /dev/null 2>&1 ); then
        g.message -v message="table $m exists, deleting"
        db.droptable -f table=$m
      fi
    done
  fi

  if (v.info -t z_normal > /dev/null 2>&1 ); then
    g.message -v message='vector z_normal exists'
  else
    [[ -d $d ]] || mkdir $d;
    if [[ -f $d/data.json ]]; then
      g.message -v message="$d/data.json exists"
    else
      local stations
      if [ -n "$GIS_OPT_STATIONS" ] ; then
        stations=$(echo $GIS_OPT_STATIONS | tr ' ' ',')
      else
        stations=$(v.db.select -c map=station column=StationNbr | tr '\n' ',' | sed 's/,$//')
      fi
      local link
      link=$(printf '%s/data?appKey=%s&targets=%s&dataItems=%s&startDate=%s&endDate=%s&unitOfMeasure=M' ${GBL[api]} ${GBL[appkey]} $stations ${GBL[items]} ${GBL[YYYY-MM-DD]} ${GBL[YYYY-MM-DD]})
      g.message -v message="curl $link > $d/data.json"
      curl "$link" > $d/data.json
    fi;

    if [[ -f $d/data.vrt ]]; then
      g.message -v message="$d/data.vrt exists"
    else
      cat <<EOF > $d/data.vrt
<OGRVRTDataSource>
 <OGRVRTLayer name="data">
  <SrcDataSource>data.csv</SrcDataSource>
  <Field name="StationNbr" type="Integer" />
  <Field name="day_asce_eto" type="Real" />
  <Field name="day_asce_eto_qc" type="String" />
  <Field name="day_precip" type="Real" />
  <Field name="day_precip_qc" type="String" />
  <Field name="day_sol_rad_avg" type="Real" />
  <Field name="day_sol_rad_avg_qc" type="String" />
  <Field name="day_vap_pres_avg" type="Real" />
  <Field name="day_vap_pres_avg_qc" type="String" />
  <Field name="day_air_tmp_max" type="Real" />
  <Field name="day_air_tmp_max_qc" type="String" />
  <Field name="day_air_tmp_min" type="Real" />
  <Field name="day_air_tmp_min_qc" type="String" />
  <Field name="day_air_tmp_avg" type="Real" />
  <Field name="day_air_tmp_avg_qc" type="String" />
  <Field name="day_rel_hum_max" type="Real" />
  <Field name="day_rel_hum_max_qc" type="String" />
  <Field name="day_rel_hum_min" type="Real" />
  <Field name="day_rel_hum_min_qc" type="String" />
  <Field name="day_rel_hum_avg" type="Real" />
  <Field name="day_rel_hum_avg_qc" type="String" />
  <Field name="day_dew_pnt" type="Real" />
  <Field name="day_dew_pnt_qc" type="String" />
  <Field name="day_wind_spd_avg" type="Real" />
  <Field name="day_wind_spd_avg_qc" type="String" />
 </OGRVRTLayer>
</OGRVRTDataSource>
EOF
    fi


    if [[ -f $d/data.csv ]]; then
      g.message -v message="$d/data.csv exists"
    else
      jq --arg vars ${GBL[items]} -r '["StationNbr"]+([$vars | split(",")[] | gsub("-"; "_")] as $hs | [ $hs[] as $h | $h,$h+"_qc"]) , (.Data.Providers[0].Records[] | . as $item | [.Station] + ([$vars | split(",")[] | gsub("(^|-)(?<x>.)"; "\(.x | ascii_upcase)")] as $v | [ $v[] as $k | $item[$k].Value,$item[$k].Qc ])) | @csv' data.json > data.csv
    fi;

    (cd $d; db.in.ogr input=data.vrt output=data)
    g.copy --overwrite vector=station,et
    v.db.join map=et column=StationNbr other_table=data other_column=StationNbr

    g.copy --overwrite vector=et,z_normal
    v.to.db --overwrite map=z_normal option=coor columns=x,y,z

    g.message -v message="update z_normal set day_air_tmp_min=day_air_tmp_min+${GBL[lr-day_air_tmp_min]}*z/1000,day_air_tmp_max=day_air_tmp_max+${GBL[lr-day_air_tmp_max]}*z/1000,day_dew_pnt=day_dew_pnt+${GBL[lr-day_dew_pnt]}*z/1000;"

    db.execute sql="update z_normal set day_air_tmp_min=day_air_tmp_min+${GBL[lr-day_air_tmp_min]}*z/1000,day_air_tmp_max=day_air_tmp_max+${GBL[lr-day_air_tmp_max]}*z/1000,day_dew_pnt=day_dew_pnt+${GBL[lr-day_dew_pnt]}*z/1000;"
    v.support map_name="Normalized CIMIS Station parameters" map=z_normal
  fi
}

function spline() {
  local f=$1

    #v.surf.bspline input=et tension=${GBL[T_tension]} smooth=${GBL[T_smooth]} output=et_spline
    v.surf.rst npmin=100 segmax=200 input=z_normal zcolumn=$p where="${p}_qc in ('K','Y','H','',' ')" tension=5 smooth=0.05 elev=z_${p}

    v.support map_name="Normalized" map=z_${p}
    r.mapcalc --overwrite ${p}_ns expression="if(isnull(z_${p}),null(),z_${p} - ${GBL[lr-${p}]}/1000 * Z@500m/1000)"

}

G_verify_mapset
station
data
exit 0;
