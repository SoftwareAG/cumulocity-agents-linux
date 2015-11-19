# Cumulocity Linux Agent #

Cumulocity Linux agent is a generic agent for connecting to Cumulocity, which runs on all major Linux distributions (Ubuntu, Debian, Raspbian, CentOS, etc.).

### Current Features ###

* Periodically report memory usage to Cumulocity.
* Periodically report system load to Cumulocity.
* Send log files (syslog, journald, agent log) to Cumulocity on demand.

### Features in Planning ###
* Remotely restart the agent.

### How to build the agent? ###

* Build the [Cumulocity C++ library](https://bitbucket.org/m2m/cumulocity-sdk-c) with the default *Makefile* and *common.mk* as *init.mk*.
* Download the agent source code:

```
#!bash
git clone git@bitbucket.org:m2m/cumulocity-agent-linux.git

```

* Copy the compiled library files to the *lib/* directory under the agent root directory.
* Export the Cumulocity C++ library path (add the following code to your ~/.bashrc for permanence):

```
#!bash

export C8Y_LIB_PATH=/library/root/path
```

* Build the agent in *debug* mode:

```
#!bash

make
```
* Or build the agent in *release* mode:

```
#!bash

make release
```

* Run the agent:

```
#!bash

./runagent
```