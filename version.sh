#!/usr/bin/env sh
USAGE="Description: cumulocity-agent release number versioner.

Usage:
$(basename $0) -h          -- Show this help.
$(basename $0) ask         -- Show cumulocity-agent current version.
$(basename $0) <version>   -- Update version number to <version>."

if [ "$1" = "" -o "$1" = "-h" ]; then
    echo "$USAGE"
elif [ "$1" = "ask" ]; then
    echo -n "cumulocity-agent: "
    grep Version: pkg/debian/DEBIAN/control | cut -c 10-
else
    sed -i "/Version:/c\Version: $1" pkg/debian/DEBIAN/control
    sed -i "/Version:/c\Version: $1" pkg/debian/DEBIAN-remoteaccess/control
    sed -i "/AGENT_VERSION=/c\AGENT_VERSION='$1'" pkg/rpm/build_rpm.sh
    sed -i "/AGENT_VERSION=/c\AGENT_VERSION='$1'" pkg/rpm/build_rpm_monitoring.sh
    sed -i "/AGENT_VERSION=/c\AGENT_VERSION='$1'" pkg/rpm/build_rpm_remoteaccess.sh
    sed -i "/version:/c\version: $1" pkg/snap/snapcraft.yaml
    sed -i "/version:/c\version: $1" pkg/snap/snapcraft_canopen.yaml
    sed -i "/version:/c\version: $1" pkg/snap/snapcraft_remoteaccess.yaml
    sed -i "/local agentVersion/c\local agentVersion = '$1'" lua/version.lua
    sed -r -i "1s/(cumulocity-agent_).*/\1$1/g" srtemplate.txt
fi
exit 0
