#!/bin/sh
# Print Linux PSI (pressure stall information) as InfluxDB line protocol.
# measurement: pressure ; tags: resource=<memory|io|cpu>, kind=<some|full>
# fields: avg10, avg60, avg300 (floats), total (integer). No timestamp.
# Files or lines that do not exist are skipped.

BASE="${HOST_PROC:-/proc}/pressure"

for res in memory io cpu; do
  f="${BASE}/${res}"
  [ -r "$f" ] || continue
  awk -v res="$res" '
    function val(s) { sub(/^[^=]*=/, "", s); return s }
    ($1 == "some" || $1 == "full") && NF >= 5 {
      printf "pressure,resource=%s,kind=%s avg10=%s,avg60=%s,avg300=%s,total=%si\n",
        res, $1, val($2), val($3), val($4), val($5)
    }
  ' "$f"
done
