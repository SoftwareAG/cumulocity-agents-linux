# Cumulocity Linux Agent #

Cumulocity Linux agent is a generic agent for connecting to Cumulocity, which runs on all major Linux distributions (Ubuntu, Debian, Raspbian, CentOS, etc.).

### Current Features ###

* Periodically report device memory usage to Cumulocity.
* Periodically report device system load to Cumulocity.
* Send log files (syslog, journald, agent log) to Cumulocity on demand.

### Features in Planning ###
* Remotely restart the agent.

### How to build the agent? ###

* First download and build the [Cumulocity C++ library](https://bitbucket.org/m2m/cumulocity-sdk-c).
* Copy the compiled library files to the lib/ directory under the agent root directory.
* Export the Cumulocity C++ library path (add the following code to your ~/.bashrc if you don't want to set it every time after reboot):

```
#!bash

export export C8Y_LIB_PATH=/library/root/path
```

* Build the agent in *debug* mode:

```
#!bash

make
```
* Build the agent in *release* mode:

```
#!bash

make release
```

* Run the agent:

```
#!bash

./runagent
```