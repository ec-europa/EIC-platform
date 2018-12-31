EIC Case Tracker Application
=======

This module is part of the EIC Platform.

## Dependencies

The case tracker is designed to run in its own eXist-DB instance. 

Runs inside [eXist-DB](http://exist-db.org/) (version 4.3.1)

Back-end made with [Oppidum](https://www.github.com/ssire/oppidum/) XQuery framework

Front-end made with [AXEL](http://ssire.github.io/axel/), [AXEL-FORMS](http://ssire.github.io/axel/) and [Bootstrap](http://twitter.github.io/bootstrap/) (all embedded inside the `resources` folder)

PDF generation using Apache FOP, see [Install Guide of Apache FO Processor 1.1 in eXist-DB](./docs/install-fop-module.md)

## History

This work has been initiated and supported by the CoachCom2020 coordination and support action (H2020-635518; 09/2014-08/2016). Coachcom 2020 has been selected by the European Commission to develop a framework for the business innovation coaching offered to the beneficiaries of the Horizon 2020 SME Instrument.

## License

Parts of this work are licensed under the European Union Public Licence [EUPL](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12).

Parts of this work are subject to intellectual property restrictions, please consult us for more information.

## Installation

First you need to install eXist-DB.

Make sure the following XQuery modules are enabled in eXist-DB `conf.xml` file :

* `<module uri="http://exist-db.org/xquery/compression"...`
* `<module uri="http://exist-db.org/xquery/image"...`
* `<module uri="http://exist-db.org/xquery/mail"...`

(DEPRECATED) If not pre-installed in your eXist-DB version, install Apache FOP (this should be run only once) :

    cd EXIST-HOME/webappp/projects
    cd cctracker/scripts
    ./install_fop-1.1.sh

You must restart eXist-DB to take those changes into effect.

Then create a *projects* folder inside your EXIST-HOME/webapp folder, and get sure you get all these modules available :

    cd EXIST-HOME/webappp/projects
    git clone -b exist-4 https://github.com/ssire/oppidum.git oppidum
    git clone -b exist431 [EIC Case Tracker Application].git cctracker
    git clone -b exist431 [EIC Platform Configuration].git platform
    git clone [EIC XQuery Content Management Framework].git excm
    git clone [EIC XML front-end framework].git exfront

Start the database, set the admin password to {pwd}, then run :

    cd EXIST-HOME/webappp/projects/cctracker/scripts
    ./install.sh {pwd}

(DEPRECATED) This should create a sample user with username *demo* and admin system role (any password can be used with simulated login in *dev* mode). You can use this user to add more persons (in Community > Person profile section) and to assign roles to these persons (in Admin > Users section). Because of the EU Login access you do not need to create users with eXist-DB internal login.

Although the case tracker is designed to received cases from a web service API (or to import cases from Excel files using a service available at the hidden `/import` DEPRECATED url), you can create cases for testing with the secrete url : `/cases/create`. Alternatively you can do a database restoration as explained below.

To start using the Case Tracker you need to make a database restoration from a production server.

## Database restoration

To fill your case tracker database with data from another case tracker backup you only need to restore the `db/sites` collection (assuming your are restoring from a case tracker running with a data model compatible version).

For instance using a `full20171011-1454.zip` full backup archive :
  
    cd {path to backups}
    unzip full20171011-1454.zip
    cd {EXIST-HOME}
    ./bin/backup.sh -u admin -p {pwd} -r {path to backups}/full20171011-1454/db/sites/__contents__.xml

The restoration will overwrite the *demo* user and any other data you created during the initial installation. In order to test the application with the *demo* user you need to edit the `/db/sites/cctracker/persons/{bucket}/{id}.xml` resource in database. Select a *Person* record with a *UserProfile* (prefer one with a *Role/FunctionRef* set to 1 to pick up a system administrator so that you can have access to all functionalities), then replace existing *Remote* element or add it inside the *UserProfile* element :

    <Remote Name="ECAS">demo</Remote>

The *demo* user should then take the identity of the *Person* you edited (you can check by clicking on the *demo* login name on the screen upper right corner once logged in).

(DEPRECATED) It is possible that some image files from the `/db/sites/cctracker/persons/xxxx/images` cannot be restored because their *owner* attribute refers to an unknown eXist-DB user. If this happens edit the `/db/sites/cctracker/persons/xxxx/images/__content__.xml` file and set every owner attribute to `owner="admin"` as in :

    <resource type="BinaryResource" name="24.jpeg" skip="no" owner="admin" group="users" mode="774" created="2015-10-22T09:37:45+02:00" modified="2015-10-22T09:37:45+02:00" filename="24.jpeg" mimetype="image/jpeg"/>

The restore the `/db/sites/cctracker/persons/xxx/images/__content.xml` collection, this should fix the problem.

## Extra configuration

The *debug* target of case tracker deploy command installs :

* a `debug.xml` file containing an empty `<Debug/>` root element. It will keep track of e-mail sent by the application, even if the e-mail server is disactivated with ! (typically `!localhost` see `settings.xml)
* a `login.xml` file containing an empty `<Login/>` root element. It will keep track of login to your application

MORE: caches, indexes

MORE: nightly backup configuration

MORE: nightly jobs configuration todos and reminders

For reminders nightly job do not forget to run the deploy script with the _jobs_ target. In addition you must manually install `/db/www/oppidum/lib/util.xqm` file into the database from Oppidum distribution. This is because the nighlty jobs can only execute files stored inside the database.

##Coding conventions

* _soft tabs_ (2 spaces per tab)
* no space at end of line (ex. with sed : `sed -E 's/[ ]+$//g'`)

