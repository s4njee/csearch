#!/bin/sh

exec tar --zstd -cvf /archives/congress.$(date +%Y.%m.%d).tar.zst /congress