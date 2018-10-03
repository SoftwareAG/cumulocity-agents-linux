#!/usr/bin/env sh
USAGE="Description: cumulocity-agent release number versioner.

Usage:
$(basename $0) -h          -- Show this help.
$(basename $0) ask         -- Show cumulocity-agent current version.
$(basename $0) <version>   -- Update version number to <version>."

if [ "$1" == "" -o "$1" == "-h" ]; then
    echo "$USAGE"
elif [ "$1" == "ask" ]; then
    echo -n "cumulocity-agent: "
    grep Version: pkg/debian/DEBIAN/control | cut -c 10-
else
    sed -i "/Version:/c\Version: $1" pkg/debian/DEBIAN/control
fi
exit 0


