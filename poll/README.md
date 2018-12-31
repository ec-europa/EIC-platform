EIC Poll Application
=====

Initial version : Stéphane Sire <s.sire@oppidoc.fr>

The Poll application is a feedback questionnaire service platform

You can call it from 3rd party web applications to :

- upload and create feedback questionnaires from XML Questionnaire specifications
- upload and create (resp. cancel, close) orders to generate unique links to complete feedback questionnaires
- allow guest users (no login) to complete a feedback questionnaire and post answers to a web hook inside a 3rd party application

It uses an XML Questionnaire specification language to define the questions and an optional web hook where to post the answers

## Quick Installation

This application actually runs on eXist-DB 1.4.3. It should be configured to run on port 9090 for Case Tracker integration.

First install eXist-DB. You may follow these [installation notes](https://github.com/ssire/oppidum/wiki/exist-db-installation-notes).

Then (calling your projects folder *projects* but you can choose any other name) :

    cd EXIST_HOME/webapp
    mkdir projects
    # Oppidum installation
    git clone https://github.com/ssire/oppidum.git
    cd oppidum/scripts
    ./bootstrap.sh PASSWD
    # Poll module installation
    cd ../..
    git clone [EIC Poll Application].git poll
    cd poll/scripts
    ./bootstrap.sh PASSWD
    cd ../..
    # Integration with Case Tracker
    git clone [EIC Platform Configuration].git platform
    cd platform/scripts
    ./bootstrap.sh PASSWD

For Case Tracker integration you must run the platform post-deployment script :

    curl "http://localhost:9090/exist/projects/platform/deploy?pwd=PASSWORD&m=dev"

After installation :

1. create a *poll* user with eXist-DB administration tools, this user can login to the application and watch the orders (resp. `/login` and `/admin`)
2. create a user in DBA group and put that user's credentials into the `Sudoer` element of `/db/www/config/settings.xml` (copied from `config/settings.xml` when deploying). This is required to allow poll application to execute an XSLT transformation to install new questionnaires

## Demonstration

The application comes with a test questionnaire and a sample order (see ``scripts/test.sh``)

If you use it from a case tracker, the *services* target of the case tracker deployment script should deploy one or more questionnaires into the poll application. For that purpose do not forget to edit their respective `services.xml` configuration file.

## Implementation

This is an eXist-DB application written with the XQuery application framework Oppidum

It uses the following (embedded) libraries :

- Bootstrap (2.3.1)
- AXEL 
- AXEL-FORMS
