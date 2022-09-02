#!/bin/bash

# let's create data.json with two entries (1st and 10th day of month) each in months feb, april, jun, aug, oct, dec for years 2019, 2020, 2021, 2022.

str="$(printf '%s\n' {1,10}' '{feb,apr,jun,aug,oct,dec}' '{2019,2020,2021,2022})"

while read s; do
    secs=$(date -d "$s" +%s)

    echo $secs
done < <(echo "$str")
