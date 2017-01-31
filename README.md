# Cumulocity Linux Agent #

Cumulocity Linux agent is a generic agent for connecting Linux-powered devices to Cumulocity's IoT platform. It runs on all major Linux distributions (Ubuntu, Debian, Raspbian, CentOS, etc.).

### Current Features ###

* Periodically report memory usage to Cumulocity.
* Periodically report system load to Cumulocity.
* Send log files (dmesg, syslog, journald, agent log) to Cumulocity on demand.

### How to build the agent? ###

* Prerequisites:
    - Linux (>= 2.6.32)

    - liblua (>= 5.1)

    - libcurl (>= 7.26.0)

    - Systemd (optional, for automatically starting the agent on boot)

* Build the [Cumulocity C++ library](https://bitbucket.org/m2m/cumulocity-sdk-c) with the default *Makefile* and *common.mk* as *init.mk*.
* Download the agent source code:

```bash
git clone git@bitbucket.org:m2m/cumulocity-agents-linux.git

```

* Export the Cumulocity C++ library path (add the following code to your ~/.bashrc for permanence):

```bash
export C8Y_LIB_PATH=/library/root/path
```
* Copy the compiled library files to the *lib/* directory under the agent root directory.

```bash
cd cumulocity-agents-linux
cp -rP $C8Y_LIB_PATH/lib $C8Y_LIB_PATH/bin .
```

* Build the agent: 
```bash
make # in *debug* mode:
```

Or

```bash
make release # in *release* mode:
```

* Install the agent:
```
sudo make install
```

* Run the agent:

```bash
sudo cumulocity-agent
```

### FAQ ###
* How can I uninstall the agent?

  Run:
```bash
sudo make uninstall
```

* How to build and package the agent as a Ubuntu snap?

  The requirements are the same as above, but the build requires special treatment because Ubuntu Snap Core uses its own file system structure, instead do:
```bash
make release  PREFIX=/snap/cumulocity-agent/current/usr DATAPATH=/var/snap/cumulocity-agent/common
make snap PREFIX=/snap/cumulocity-agent/current/usr DATAPATH=/var/snap/cumulocity-agent/common
```

This will create the snap package. Then the agent needs to be installed in developer mode, since snap sandboxing is currently too restrictive. To install it run:
```bash
sudo snap install <agent.snap> --devmode
```

The agent starts automatically after installation, also at every time the machine boots.

NOTE: packaging requires snapcraft >= 2.10 because lower versions do not support the confinement property, which is required for packaging the agent as a snap.
