drop schema if exists cimis cascade;
create schema cimis;

drop table if exists cimis.zip_et0 cascade;
create table cimis.zip_et0 (
zipcode char(5),
eto float,
k float,
eto_rms float,
eto_dish float,
k_dish float,
ymd date,
doy integer
);

truncate cimis.zip_et0;
copy cimis.zip_et0 from '/docker-entrypoint-initdb.d/avg_by_zip.csv' with csv header;

alter database :DBNAME set search_path to public,cimis;
