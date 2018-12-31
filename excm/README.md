EIC XQuery Content Management Framework (excm)
===

Shared libraries and modules to build content management applications with eXist-DB and Oppidum.

The *lib* folder contains pure XQuery libraries (API)

The *modules* folder contains XQuery libraries and associated XQuery controllers you can map to routes in your application

Pre-requisite
-------

Most of the time libraries and controllers create or act on database entities that must follow conventions to be compatible (collection or resource naming conventions and data modelling conventions, e.g. tag names).

You must configure and deploy the *globals* target in your application at least once to create the `globals.xml` file in database to resolve paths for application entities invoked with the `globals:doc()` and `globals:collection()` functions.

License
-------

European Union Public Licence [EUPL](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12)
