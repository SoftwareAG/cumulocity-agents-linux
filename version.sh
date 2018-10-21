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
    sed -i "/AGENT_VERSION=/c\AGENT_VERSION='$1'" pkg/rpm/build_rpm.sh
    sed -i "/version:/c\version: $1" pkg/snap/snapcraft.yaml
    sed -i "/local agentVersion/c\local agentVersion = '$1'" lua/software.lua
    sed -i "/cumulocity-agent_/c\cumulocity-agent_$1" srtemplate.txt
fi
exit 0


