EIC SME Dashboard Application
=======

This module is part of the EIC Platform

Dashboard application to group access to Business Acceleration services

## Dependencies

Runs inside [eXist-DB](http://exist-db.org/) (developed with [version 3.2.0](https://bintray.com/existdb/releases/exist))

Back-end made with [Oppidum](https://www.github.com/ssire/oppidum/) XQuery framework

Front-end made with [AXEL](http://ssire.github.io/axel/), [AXEL-FORMS](http://ssire.github.io/axel/) and [Bootstrap](http://twitter.github.io/bootstrap/) (all embedded inside the `resources` folder)

## License

European Union Public Licence [EUPL](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12)

## Installation

First you need to install eXist-DB. Install [eXist-DB](https://bintray.com/existdb/releases/exist) (the application has been developed with eXist-DB 3.2.0), you can follow these [installation notes](https://github.com/ssire/oppidum/wiki/exist-db-installation-notes).

Then create a *projects* folder inside your EXIST-HOME/webapp folder, and get sure you get all these modules available :

    cd EXIST-HOME/webappp/projects
    git clone https://github.com/ssire/oppidum.git oppidum
    git clone [EIC SME Dashboard Application].git cockpit
    git clone [EIC XQuery Content Management Framework].git excm
    git clone -b devel [EIC Legacy XQuery Content Management Framework].git xcm
    git clone [EIC Taxonomies framework].git taxonomies
    git clone -b exist22 [EIC Platform Configuration].git platform
    
You should then get the following file layout in your *projects* folder :

    $ ls
    cockpit  excm  oppidum  platform  taxonomies  xcm

## Configuration

In this step you will boostrap the depots cloned during installation. This step is only required once and must be performed with eXist-DB running. You MUST have installed eXist-DB with a non empty eXist-DB password.

    cd EXIST-HOME/webapp/projects/cockpit/scripts
    ./install.sh {admin password}
    ./init.sh {admin password} {mode}

If you restore a full database backup from a production environment, you should run the command :

    ./restore.sh {admin password} {mode}

If you update the current branch, you should run the command :

    ./switch.sh {admin password} {mode}

**NOTE** : the configuration step can only be run from the local machine since the deploy command check the URL contains a *localhost* or *127.0.0.1* domain name

## Data restoration

Unzip a full SME Dashboard database backup somewhere (e.g. `full20180314-1407.zip`), here is an example :

    $ ls -1 /PATH-TO.../full20180314-1407/db/
    __contents__.xml
    apps
    batch
    binaries
    caches
    debug
    sites
    system
    www

Restore at least the *sites* collection to start testing (you can also restore *binaries* for uploaded user data) :

    ./bin/backup.sh -u admin -p PASSWORD -r /PATH-TO.../full20180314-1407/db/sites/__contents__.xml
    ./bin/backup.sh -u admin -p PASSWORD -r /PATH-TO.../full20180314-1407/db/binaries/__contents__.xml

You can then open [http://localhost:PORT/exist/projects/cockpit](). To login, since you are running the application in dev mode, you can use any Remote name (with any password string) as found in user account resources inside `/db/sites/cockpit/persons` sub-collections (you can read them from your backup directory), for instance you can login with *demo* if some resource contains :

    <Remote Name="ECAS">demo</Remote>

## Coding conventions

* _soft tabs_ (2 spaces per tab)
* no space at end of line (ex. with sed : `sed -E 's/[ ]+$//g'`)

