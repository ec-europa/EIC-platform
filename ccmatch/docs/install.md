Coach Match Installation
========================

Author: Stéphane Sire, Oppidoc, <s.sire@oppidoc.fr> (Last edit 2015-11-20)

## 1. Install eXist-1.4.3 (DEPRECATED: now 2.2)

Create _coachmatchserv_ user and group to execute eXist-DB (unless you only want to develop, then you can configure/leave yourself as owner)

    sudo groupadd coachmatchserv
    sudo useradd -g coachmatchserv coachmatchserv

Follow these [installation notes](https://github.com/ssire/oppidum/wiki/exist-db-installation-notes)

After installation you should get the following directories :

- `/usr/local/ccmatch/lib` : EXIST-HOME
- `/usr/local/ccmatch/data` : database files (configured in `EXIST-HOME/conf.xml`)
- `/usr/local/ccmatch/logs` : database execution traces (configured in `log4j.xml`)
- `/usr/local/ccmatch/run` : pid file location (only if run as unix daemon)

Set file system permission for _coachmatchserv_ :

    sudo chown -R coachmatchserv:coachmatchserv /usr/local/ccmatch/lib /usr/local/ccmatch/data
    sudo chown -R coachmatchserv:coachmatchserv /usr/local/ccmatch/logs /usr/local/ccmatch/run

Configure network port (e.g. 7070) :

    sudo vim EXIST-HOME/tools/jetty/etc/jetty.xml
    
- line 51: `<SystemProperty name="jetty.port" default="7070"/>`

Configure the eXist-DB instance :

    sudo vim EXIST-HOME/conf.xml

- line 138: edit `cacheSize="48M" collectionCache="24M"` rule of thumb is to not give more than 1/3 total memory to cache size
- line 437 and below : schedule your backup job
- line 688 and below : uncomment Image and Mail XQuery modules

Configure `EXIST-HOME/log4j.xml` to point to your logs location :

- replace all log file paths `../logs` with your location `usr/local/ccmatch/logs`
- set all priority level to warn to decrease log verbosity 
    - replace all `value="debug"` with `value="warn"`
    - replace all `value="info"` with `value="warn"

Note that if you use the daemon launcher (production mode, see below) then you must also configure _log4j.xml_ in another location. In that case you must configure it in both location because the eXist-DB command lines tools will still continue to use the `EXIST-HOME/log4j.xml` configuration file.

Then you can start eXist-DB :

- `EXIST-HOME/bin/startup.sh &` (development mode)
- `sudo service coachmatchdb start` (production mode, see below)

Check eXist-DB properties file and adjust them to your port :

- `client.properties`
- `backup.properties`

Check all the command line tools you intend to use in `EXIST-HOME/bin` point to the correct path :

- line 10 of _client.sh_ : EXIST_HOME="/usr/local/ccmatch/lib"
- line 10 of _startup.sh_ 
- line 10 of _shutdown.sh_ 
- _etc_

They should be set by the eXist-DB installer, but for instance if you create a new installation by copying an existing one, you must adjust them.

### Extra steps for configuring the application as a service (unix daemon)

All the commands below are entered from `EXIST-HOME`

Get latest version of Java service wrapper at [http://www.tanukisoftware.com/en/wrapper.php]()

For instance with `wrapper-linux-x86-64-3.5.24` :

    cd EXIST-HOME
    cp {WRAPPER_HOME}/wrapper-linux-x86-64-3.5.24/bin/wrapper tools/wrapper/bin
    cp {WRAPPER_HOME}/wrapper-linux-x86-64-3.5.24/lib/libwrapper.so tools/wrapper/lib
    cp {WRAPPER_HOME}/wrapper-linux-x86-64-3.5.24/lib/wrapper.jar tools/wrapper/lib

Check or update wrapper configuration file 

    sudo vim tools/wrapper/conf/wrapper.conf
    
- line 9 : `set.EXIST_HOME=/usr/local/ccmatch/lib`
- line 36 : `wrapper.java.initmemory=1024`
- line 39 : `wrapper.java.maxmemory=1536`
- line 55 : `wrapper.logfile=/usr/local/ccmatch/logs/wrapper.log`

Check or update wrapper shell script 

    sudo vim tools/wrapper/bin/exist.sh
    
- line 28 : `PIDDIR="/usr/local/ccmatch/run"`
- line 45 : `RUN_AS_USER=coachmatchserv`

Install service (Debian syntax), our convention is to call it _coachmatchdb_ :

    sudo ln -s /usr/local/ccmatch/lib/tools/wrapper/bin/exist.sh /etc/init.d/coachmatchdb
    sudo update-rc.d coachmatchdb defaults

The wrapper controls eXist-DB with the script `EXIST-HOME/tools/wrapper/bin/exist.sh`, check it contains the correct paths :

- line 20 : WRAPPER_CMD="/usr/local/ccmatch/lib/tools/wrapper/bin/wrapper"
- line 21 : WRAPPER_CONF="/usr/local/ccmatch/lib/tools/wrapper/conf/wrapper.conf" 

For use with wrapper, edit `EXIST-HOME/tools/wrapper/conf/log4j.xml` configuration file.

- replace all log file paths `../logs` with your location `usr/local/ccmatch/logs`
- set all priority level to warn to decrease log verbosity 
    - replace all `value="debug"` with `value="warn"`
    - replace all `value="info"` with `value="warn"
    
### Extra steps to remove unnecessary servlets and improve security

Edit `EXIST_HOME/webapp/WEB-INF/web.xml` 

_To be explained_

Edit `EXIST_HOME/webapp/WEB-INF/controller-config.xml`

_To be explained_

## 2. Install Oppidum

Follow the [How to install it ?](http://www.github.com/ssire/oppidum/) section of the Oppidum README file

Basically you should get the following directory :

- `/usr/local/ccmatch/lib/webapp/projects/oppidum` : Oppidum home

Do not forget to execute Oppidum post-installation script _bootstrap.sh_ as explained. Always check `EXIST-HOME/client.properties` points to the correct port before executing it. 

## 3. Clone Oppistore and Coach Match Git depots

Note that inherently to Oppidum you need to clone all your projects inside the same _projects_ folder inside eXist-DB _webapp_ folder

### Using HTTPS

    cd /usr/local/ccmatch/lib/webapp/projects
    git clone https://{your login}@bitbucket.org/ssire/ccmatch.git

### Using SSH (if you registered your own SSH key inside your bitbucket profile)

    cd /usr/local/ccmatch/lib/webapp/projects
    git clone git@bitbucket.org:votre-login-bitbucket/ccmatch.git

On Mac OS X you need to configure your SSH-agent to use you SSH Key (see available online tutorials)
