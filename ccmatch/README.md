EIC Coach Match Application 
=======

This module is part of the EIC Platform.

The suggestion algorithm can be invoked :

* directly from within Coach Match using the *Coach search* menu tabs
* from a third party Case Tracker using the suggestion tunnel

## Dependencies

Runs inside [eXist-DB](http://exist-db.org/) ([version 2.2](http://sourceforge.net/projects/exist/files/Stable/2.2/))

Back-end made with [Oppidum](https://www.github.com/ssire/oppidum/) XQuery framework

Front-end made with [AXEL](http://ssire.github.io/axel/), [AXEL-FORMS](http://ssire.github.io/axel/) and [Bootstrap](http://twitter.github.io/bootstrap/) (all embedded inside `resources` folder)

EIC XQuery Content Management framework 

EIC XML front-end framework (or libraries)

EIC Platform integration with platform depot 

## History

This work has been initiated and supported by the CoachCom2020 coordination and support action (H2020-635518; 09/2014-08/2016). Coachcom 2020 has been selected by the European Commission to develop a framework for the business innovation coaching offered to the beneficiaries of the Horizon 2020 SME Instrument.

## License

Parts of this work are licensed under the European Union Public Licence [EUPL](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12).

Parts of this work are subject to intellectual property restrictions, please consult us for more information.

## Installation

First you need to install eXist-DB, see [install.md](./docs/install.md)

Then create a *projects* folder inside your EXIST-HOME/webapp folder, and get sure you get all these modules available :

    cd EXIST-HOME/webappp/projects
    git clone https://github.com/ssire/oppidum.git oppidum
    git clone -b exist22 [EIC Coach Match Application].git ccmatch
    git clone [EIC XQuery Content Management Framework].git excm
    git clone [EIC XML front-end framework].git exfront
    git clone -b exist22 [EIC Platform Configuration].git platform

## Configuration 

Coach Match is designed to run side-by-side with a Case Tracker application.

Each application is running in its own eXist-DB instance. We currently have deployed both instances on the same virtual machine, each instance is defined to run on a different port.

For instance :

- Case Tracker port : 8080
- Coach Match port : 7070

The Case Tracker will call the coach suggestion service at _http://{Coach Match Address}/suggest (POST)_

Coach Match will call the case tracker user export service at _http://{Case Tracker Address}/coaches/export (POST)_

In development mode you manually start / stop the database and you work with long URL like `http://localhost:7070/exist/projects/ccmatch` 

In production mode you configure the database as a service (unix Daemon) and remap URL with a reverse proxy (e.g. Nginx) so that you use short URL like `https://www.coachmatch.com` (note SSL can be added at proxy level)

Basically all you need to do to bootstrap the application on an empty database right after cloning is :

    cd EXIST-HOME/webapp/projects/ccmatch/scripts
    ./install.sh {admin password}
    ./init.sh {admin password} {mode} 

then follow the instructions... (see [detailed configuration instructions](./docs/configuration.md)).

You can then (in dev mode) use the demo login and any password to access the application.

## Deployment

Current procedure is to pull the desired version from the code depot, then use the deployment script to synchronize the in-database configuration with the file system configuration if you have updated it. This is done with the scripts/switch.sh script.

The *account-availabilities* and *account-visibilities* formulars which are embedded into the home page are generated once with all their input fields complete (no dynamical extension points). Hence be sure to have deployed the data targets before deploying the forms target (this is integrated in the deployment script).

Note that the `settings.xml` and `services.xml` are not integrated into the deployment script because they must be deployed from a platform depot.

## Software manual

- [commands.md](./docs/commands.md) :  Javascript commands

## Coding conventions

* _soft tabs_ (2 spaces per tab)
* no space at end of line (ex. with sed : `sed -E 's/[ ]+$//g'`)
