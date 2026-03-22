drop schema if exists cimis cascade;
create schema cimis;

alter database :DBNAME set search_path to cimis,public;

drop table if exists cimis.stats cascade;
CREATE TABLE cimis.stats (
  cat integer,
  DAU_CODE varchar(3) ,
  "date" date,
  doy integer,
  Tn_average DOUBLE PRECISION,
  Tn_stddev DOUBLE PRECISION,
  Tn_d_diff_average DOUBLE PRECISION,
  Tn_d_diff_stddev DOUBLE PRECISION,
  Tx_average DOUBLE PRECISION,
  Tx_stddev DOUBLE PRECISION,
  Tx_d_diff_average DOUBLE PRECISION,
  Tx_d_diff_stddev DOUBLE PRECISION,
  U2_average DOUBLE PRECISION,
  U2_stddev DOUBLE PRECISION,
  U2_d_diff_average DOUBLE PRECISION,
  U2_d_diff_stddev DOUBLE PRECISION,
  Rs_average DOUBLE PRECISION,
  Rs_stddev DOUBLE PRECISION,
  Rs_d_diff_average DOUBLE PRECISION,
  Rs_d_diff_stddev DOUBLE PRECISION,
  K_average DOUBLE PRECISION,
  K_stddev DOUBLE PRECISION,
  K_d_diff_average DOUBLE PRECISION,
  K_d_diff_stddev DOUBLE PRECISION,
  Rnl_average DOUBLE PRECISION,
  Rnl_stddev DOUBLE PRECISION,
  Rnl_d_diff_average DOUBLE PRECISION,
  Rnl_d_diff_stddev DOUBLE PRECISION,
  ETo_average DOUBLE PRECISION,
  ETo_stddev DOUBLE PRECISION,
  ETo_d_diff_average DOUBLE PRECISION,
  ETo_d_diff_stddev DOUBLE PRECISION,
   primary key(cat,date)
);
