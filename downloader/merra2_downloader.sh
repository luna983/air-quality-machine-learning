#!/bin/bash

for var in AODANA COSC PBLH PS RH T2M TO3 U2M V2M
do
    echo "Downloading $var..."
    rm ../../data/raw/$var/*.nc
    nohup wget --content-disposition --http-user=luna983 --http-password=Luna_983 --keep-session-cookies -i ../../data/raw/links/merra2/$var.txt -P ../../data/raw/$var/ &> $var.log &
done
