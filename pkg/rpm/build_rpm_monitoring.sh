#!/bin/bash

PACKAGE_BASE=/var/tmp/c8y
SRC_ROOT=$(pwd)
TARGET_BASE=/usr/share/cumulocity-agent
DATAPATH=/var/lib/cumulocity-agent
PREFIX=/usr
RPM_BASE=/tmp/rpmbuild
AGENT_VERSION='4.2.9'
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

Summary: Cumulocity Linux Agent
Name: cumulocity-agent
Version: $AGENT_VERSION
Release: $RPM_RELEASE
License: Commercial
Group: Development/Tools
URL: http://www.cumulocity.com/

Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-root

Requires: redhat-lsb-core, lua

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
mkdir -p %{buildroot}$TARGET_BASE
mkdir -p %{buildroot}$DATAPATH
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/local/lib
mkdir -p %{buildroot}/etc
mkdir -p %{buildroot}/etc/ld.so.conf.d
mkdir -p %{buildroot}$TARGET_BASE/lua
mkdir -p %{buildroot}/usr/lib/systemd/system
mkdir -p %{buildroot}/usr/share/doc/cumulocity-agent
mkdir -p %{buildroot}/usr/lib64/lua/5.1
mkdir -p %{buildroot}/usr/lib64/lua/5.1/posix

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

#template copy
cp $SRC_ROOT/srtemplate.txt %{buildroot}$TARGET_BASE

#service file creation
touch %{buildroot}/usr/lib/systemd/system/cumulocity-agent.service

#copy copyright file
cp $SRC_ROOT/COPYRIGHT %{buildroot}/usr/share/doc/cumulocity-agent

#copy luaposix library and its dependency
cp /usr/lib64/lua/5.1/bit32.so %{buildroot}/usr/lib64/lua/5.1
cp -r /usr/lib64/lua/5.1/posix/* %{buildroot}/usr/lib64/lua/5.1/posix

sed -r -e 's#[$]PREFIX#'"$PREFIX"'#g' ${SRC_ROOT}/utils/cumulocity-agent.service> %{buildroot}/usr/lib/systemd/system/cumulocity-agent.service
sed -r -e 's#[$]PKG_DIR#'"$TARGET_BASE"'#g' -e 's#[$]DATAPATH#'"$DATAPATH"'#g' ${SRC_ROOT}/cumulocity-agent.conf > %{buildroot}/etc/cumulocity-agent.conf

%post
ldconfig
ln -f -s /etc/cumulocity-agent.conf $TARGET_BASE/cumulocity-agent.conf
ln -f -s lua/monitoring $TARGET_BASE/monitoring
ln -f -s $TARGET_BASE/monitoring/hosts.lua /etc/monitoring-hosts.lua
ln -f -s $TARGET_BASE/monitoring/plugins.lua /etc/monitoring-plugins.lua

systemctl enable cumulocity-agent

%postun
rm -f $TARGET_BASE/cumulocity-agent.conf
rm -f /etc/monitoring-hosts.lua
rm -f /etc/monitoring-plugins.lua
rm -f $TARGET_BASE/monitoring


%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/usr/lib/systemd/system/cumulocity-agent.service
/etc/cumulocity-agent.conf
/etc/ld.so.conf.d/cumulocity-agent-lib.conf
/usr/bin/*
/usr/local/lib/*
/usr/share/doc/cumulocity-agent/COPYRIGHT
/usr/lib64/lua/5.1/*
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
