#!/usr/bin/env bash

# beware: this script is only good up to sf1000, beyond we need more query streams and more update sets

set -euxo pipefail

DIR=gen/sf$SF
DBGEN_PREFIX=tpch_tools_3.0.1/dbgen
case $SF in
    1) REFRESH_STREAMS=2 ;;
    10) REFRESH_STREAMS=3 ;;
    30) REFRESH_STREAMS=4 ;;
    100) REFRESH_STREAMS=5 ;;
    300) REFRESH_STREAMS=6 ;;
    1000) REFRESH_STREAMS=7 ;;
    3000) REFRESH_STREAMS=8 ;;
    10000) REFRESH_STREAMS=9 ;;
    30000) REFRESH_STREAMS=10 ;;
    100000) REFRESH_STREAMS=11 ;;
    *) echo "No REFRESH_STREAMS value defined for SF=$SF" >&2; exit 1 ;;
esac

REFRESH_STREAMS=$((REFRESH_STREAMS + 1))
QUERY_STREAMS=$((REFRESH_STREAMS))

rm -rf $DIR
mkdir -p $DIR

cd $DBGEN_PREFIX
# stream 0 is the power test, streams 1..S are the throughput test (clause 5.3.5.2)
for i in `seq 0 $((QUERY_STREAMS - 1))`; do
    ./qgen -s $SF -p ${i} > queries${i}.sql
done
cd ../..
mv $DBGEN_PREFIX/queries*.sql $DIR

# cleanup
rm -f $DBGEN_PREFIX/*.tbl $DBGEN_PREFIX/*.tbl.u* $DBGEN_PREFIX/delete.*

# generate static files (tbl)
(cd $DBGEN_PREFIX && tpchgen-cli -s $SF)
mv $DBGEN_PREFIX/*.tbl $DIR

# generate refresh streams
(cd $DBGEN_PREFIX && ./dbgen -s $SF -U $REFRESH_STREAMS)
mv $DBGEN_PREFIX/*.tbl.u* $DBGEN_PREFIX/delete.* $DIR

# convert refresh streams and delete files to Parquet
(cd $DIR; python3 ../../convert.py)
