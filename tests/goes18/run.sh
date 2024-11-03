#! /usr/bin/env bash

e=${EPSG:=3310}
e=${GISDBASE:=/grassdb}
e=${PROJECT:=cimis}
e=${MAPSET:=PERMANENT}

function init_local_user() {
  if [[ -z ${LOCAL_USER_ID} ]]; then
    return
  fi
  local group=${LOCAL_GROUP_ID:-${LOCAL_USER_ID}}
  useradd --create-home --shell /bin/bash --uid ${LOCAL_USER_ID} --user-group  grass
  export HOME=/home/grass
  chown -R grass:grass /home/grass
  chown -R grass:grass /grassdb
}

create=""
if [[ -d ${GISDBASE}/${PROJECT} ]]; then
  if [[ ! -d ${GISDBASE}/${PROJECT}/${MAPSET} ]]; then
    create="-c"
  fi
  if [[ -n ${LOCAL_USER_ID} ]]; then
    init_local_user
    exec setpriv --reuid=grass --regid=grass --init-groups -- grass --text ${create} ${GISDBASE}/${PROJECT}/${MAPSET} --exec $@
  else
    grass --text ${create} ${GISDBASE}/${PROJECT}/${MAPSET} --exec $@
  fi
else
  echo 2<&1 "No such directory: ${GISDBASE}/${PROJECT}"
  exit 1
fi
