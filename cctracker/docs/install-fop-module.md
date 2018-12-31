Install Guide of Apache FO Processor 1.1 in eXist-DB
====================================================

Dependencies
----------

Runs inside [eXist-DB](http://exist-db.org/) ([version 1.4.3](http://sourceforge.net/projects/exist/files/Stable/1.4.3/))

Overview
-------

This module allows to render and generate compliant PDF file through eXist-DB as part of a MVC pipeline process.

=======================================

Installation
-------------

Note: replace _EXIST-HOME_ with the base path of your eXist-DB installation

The installer is provided as a bourne again shell script (bash) which performs all needed operations over your current install of eXist-DB. The file is located in

    _EXIST-HOME_/webapp/projects/cctracker/scripts/

Run it by performing the following command line in a shell within the above directory

    ./install_fop-1.1.sh

The installation mainly proceed as it follows:

It adds/uncomments the line 

    <module uri="http://exist-db.org/xquery/xslfo" class="org.exist.xquery.modules.xslfo.XSLFOModule"/>

which permits to eXist-DB to load the module into a XQuery script and process it within eXist-DB.

Modules and Apache FO Processor dependencies are copied into the subfolder

    _EXIST-HOME_/lib/user

and must contain the following files :
- `avalon-framework-*.jar`
- `batik-all-*.jar`
- `fop.jar`
- `xmlgraphics-commons-*.jar`
where star characted stands for the version of each file.

In order to successfully process XSL formatting file into eXist-DB, these operations are all **mandatory**.


Check the install
-----------------

_To do_

