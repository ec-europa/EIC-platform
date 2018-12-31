Platform
=======

This depot contains an SMEIMKT module called *platform*. It contains environment dependent configuration data and post-deployment scripts to bring up-to-date all the SMEIMKT modules together.

Its purpose is to allow easy **archival and deployment** of configuration data such as authorization tokens for inter-services communication or default e-mail sender addresses for different environments like *prod* or *test* or *dev* and thus to speed up the deployment of a new virtual machine or the setting up of a new test.

Synopsis
---

You must clone this depot in each of the SMEIMKT project folder in their respective eXist-DB instances.

Then boostrap once this script with (to install its `mapping.xml`) :

    cd scripts
    ./bootstrap.sh PASSWORD

After that each time you update some environment configuration, for each SMEIMKT module, re-run the platform deployment script with :

    curl "http://localhost:{PORT}/exist/projets/platform/deploy?pwd={PASSWORD}&m=(dev|test|prod)"

where {PORT} is the port number for your module and {PASSWORD} is the admin password of the database

You can only run this script from an ssh tunnel or directly from an ssh connexion to the server. This script should not be available to any user per NGINX configuration.

Manifest
---

All the platform data is stored in the `env` folder. From there you will find different categories of folders :

- env
    - {env} : *dev*, *test* or *prod*
      - system
      - {module} : *ccmatch*, *cctracker*, *poll*
          - system 
          -  config
    - scripts
    - system  
    - untracked

There is one folder for each environement that contains one folder for each module.

The `config` folders contains application configuration files to deploy in `/db/www/{module}/config` collection with the platform deployment script.

The `script` folder contains generic purpose utility scripts (e.g. *sanity-check.xql*).

The `system` folder contains system or database instance configuration files. The top level `system` folder contains environment independent files (e.g. *web.xml*, *controller-config.xml*). Then the `system` folders inside each environment contain environment dependent file (e.g. nginx *coachcom2020.conf*). Finally the `system` folders inside each module folder contains module dependent files (e.g. eXist-DB *conf.xml* file for nightly scheduled jobs).

The `untracked` folder at the top contains untracked files which are not dependent on the execution environment and which must be copied manually to one or more SMEIMKT modules :

- untracked
    - docs 
        - *common handbooks and manuals between modules*
    - tools
        - *common tools between modules*
    - cctracker
        - forum
            - specific Edinburg forum case tracker documentation 
    - iso-schematron-xslt1 (*forthcoming*)

**ATTENTION**: files in *system* and *untracked* folders must be installed manually, they are not installed by the deployment script

Updating the deployment script
---

Copy and/or update the configuration files in the dev, test or prod folders. Of course if you update some configuration dependencies between modules you must update all at once.

Once updated, if you add new configuration files then edit `scripts/deploy.xql` to register these new files in the `$smeimkt-code` variable.

You may also execute per-module post-deploy action by editing the `local:do-post-casetracker-actions`, `local:do-post-ccmatch-actions` and `local:do-post-poll-actions` in `scripts/deploy.xql`.

List of Modules
---

The table below lists the different modules currently configured via this depot

To configure an environment (dev, test or prod) launch all module eXist-DB instances, open a terminal and cut-and-paste all the configuration commands

| Module        | Port (suggested) | Configuration command (password foo, mode dev) |
|:--------------|:-----------------|:-------------------------|
| Case Tracker  | 8080             | curl "http://localhost:8080/exist/projets/platform/deploy?pwd=PASSWORD&m=dev" |
| Coach Match   | 7070             | curl "http://localhost:7070/exist/projets/platform/deploy?pwd=PASSWORD&m=dev" |
| Feedback      | 9090             | curl "http://localhost:9090/exist/projets/platform/deploy?pwd=PASSWORD&m=dev" |

Other utility scripts
---

### Log cleanup utility

Archives current debug log file `login.xml` (or `debug.xml`) content to (login|debug)-YYYY-MM-DD.xml file and resets its content in the `/db/debug` collection in database, or archives monthy histories from `/db/sites/{module}/histories` collection for every module in database and delete them except the current month. You MUST create a `debug` directory in the same parent directory as your EXIST-HOME installation, sibling of *data*, *logs* and *lib* directories to store the archives.

    curl "http://localhost:PORT/exist/projets/platform/cleanup?t=[debug|login|histories]&pwd=PASSWORD"




