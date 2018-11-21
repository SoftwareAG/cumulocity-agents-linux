#!/bin/bash

PACKAGE_BASE=/var/tmp/c8y
SRC_ROOT=/home/centos/cumulocity-agents-linux
TARGET_BASE=/usr/share/cumulocity-agent
DATAPATH=/var/lib/cumulocity-agent
PREFIX=/usr
RPM_BASE=/tmp/rpmbuild
AGENT_VERSION='2.1.0'
RPM_RELEASE='1'


# Handle commandline arguments

while getopts ":r:" opt; do
  case "$opt" in
    r)
      RPM_RELEASE=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Cleanup and create working directory

if [ -d $PACKAGE_BASE ]; then
	rm -rf $PACKAGE_BASE
fi
mkdir -p $PACKAGE_BASE

mkdir -p $RPM_BASE/{RPMS,SRPMS,BUILD,SOURCES,SPECS,tmp,stage}

cat <<EOF >~/.rpmmacros
%_topdir   /tmp/rpmbuild
%_tmppath  %{_topdir}/tmp
EOF

cat <<EOF > $RPM_BASE/SPECS/cumulocity-agent.spec
%define        __spec_install_post %{nil}
%define          debug_package %{nil}
%define        __os_install_post %{_dbpath}/brp-compress
#%define        _unpackaged_files_terminate_build 0

Summary: Cumulocity Linux Agent
Name: cumulocity-agent
Version: $AGENT_VERSION
Release: $RPM_RELEASE
License: Commercial
Group: Development/Tools
URL: http://www.cumulocity.com/

Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-root

Requires: redhat-lsb-core

%description
Cumulocity Linux Agent is a generic agent for connecting Linux-powered devices to Cumulocity's IoT platform.

Current Features:
- Periodically report memory usage to Cumulocity.
- Periodically report system load to Cumulocity.
- Send log files (dmesg, syslog, journald, agent log) to Cumulocity on demand.

%{summary}
Cumulocity Linux Agent is a generic agent for connecting Linux-powered devices to Cumulocity.

%prep

%build

%install
echo this is buildroot: --%{buildroot}--
rm -rf %{buildroot}
mkdir -p  %{buildroot}$TARGET_BASE
mkdir -p  %{buildroot}$DATAPATH
mkdir -p  %{buildroot}/usr/bin
mkdir -p  %{buildroot}/usr/local/lib
mkdir -p  %{buildroot}/etc
mkdir -p  %{buildroot}/etc/ld.so.conf.d
mkdir -p  %{buildroot}$TARGET_BASE/lua
#mkdir -p  %{buildroot}/usr/lib/nagios/plugins
mkdir -p  %{buildroot}/usr/lib/systemd/system
mkdir -p  %{buildroot}/usr/share/doc/cumulocity-agent

#config creation
touch %{buildroot}/etc/cumulocity-agent.conf

#binaries copy
cp -r $SRC_ROOT/bin/* %{buildroot}/usr/bin

#libraries copy
cp -rP $SRC_ROOT/lib/* %{buildroot}/usr/local/lib

#libraries conf copy (for ldconfig)
cp ${SRC_ROOT}/utils/cumulocity-agent-lib.conf %{buildroot}/etc/ld.so.conf.d/cumulocity-agent-lib.conf

#lua copy
cp -r $SRC_ROOT/lua/* %{buildroot}$TARGET_BASE/lua

#plugins copy
#cp -r $SRC_ROOT/lua/monitoring/plugins/* %{buildroot}/usr/lib/nagios/plugins

#template copy
cp $SRC_ROOT/srtemplate.txt %{buildroot}$TARGET_BASE

#service file creation
touch %{buildroot}/usr/lib/systemd/system/cumulocity-agent.service

#copy copyright file
cp $SRC_ROOT/COPYRIGHT %{buildroot}/usr/share/doc/cumulocity-agent

sed -r -e 's#[$]PREFIX#'"$PREFIX"'#g' ${SRC_ROOT}/utils/cumulocity-agent.service> %{buildroot}/usr/lib/systemd/system/cumulocity-agent.service
sed -r -e 's#[$]PKG_DIR#'"$TARGET_BASE"'#g' -e 's#[$]DATAPATH#'"$DATAPATH"'#g' ${SRC_ROOT}/cumulocity-agent.conf > %{buildroot}/etc/cumulocity-agent.conf

#mkdir -p  %{buildroot}$TARGET_BASE/bin %{buildroot}$TARGET_BASE/lib
#mkdir -p  %{buildroot}$TARGET_BASE/plugins
#cp -r $SRC_ROOT/lib/* %{buildroot}$TARGET_BASE/lib

%post
ldconfig
ln -f -s /etc/cumulocity-agent.conf $TARGET_BASE/cumulocity-agent.conf
systemctl enable cumulocity-agent
systemctl start cumulocity-agent

%postun
rm -f $TARGET_BASE/cumulocity-agent.conf

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/lib/systemd/system/cumulocity-agent.service
/etc/cumulocity-agent.conf
/etc/ld.so.conf.d/cumulocity-agent-lib.conf
/usr/bin/*
/usr/local/lib/*
/usr/lib/nagios/*
/usr/share/doc/cumulocity-agent/COPYRIGHT
$TARGET_BASE/*

%changelog

EOF

# Build the RPM

rpmbuild -ba $RPM_BASE/SPECS/cumulocity-agent.spec

# Rescue the RPM

mkdir -p build/rpm
cp -v $RPM_BASE/RPMS/*/cumulocity-agent*.rpm build/rpm/

# Cleanup

rm -rf $PACKAGE_BASE
rm -rf ~/.rpmmacros
rm -rf $RPM_BASE/{RPMS,SRPMS,BUILD,SOURCES,SPECS,tmp,stage}
