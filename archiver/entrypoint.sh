#!/bin/sh
 DATE=$(date +%F)
 FPATH=/csearch
 FILE=${FPATH}/congress
 TAR=${FPATH}/archives/congress.${DATE}.tar.zstd

tar --zstd -cf $TAR $FILE
