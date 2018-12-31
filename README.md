EIC Platform
===

This depot contains the source code for the modules and library frameworks composing the backbone of the EIC Community Interactive Platform. This depot is an aggregation of several depots and is published for documentation purpose only. Contact us if you are interested by deploying a similar platform, since in its current state this depot is not used for deployment.

These modules are written with the XQuery, XSLT and Javascript languages. They run in the [eXist-DB](http://exist-db.org) database management system.

Authors
-------

* Stéphane Sire (Oppidoc) <<s.sire@oppidoc.fr>>
* Frédéric Dumonceau (EASME) <<frederic.dumonceaux@ext.ec.europa.eu>>
* Iulia Chifor (EASME) <<iulia.chifor@ext.ec.europa.eu>>
* Franck Leplé (Amplexor) <<franck.leple@amplexor.com>>
* Thomas Faucher (Amplexor) <<thomas.faucher@amplexor.com>>
* Peter Winstanley (Semantechs Consulting Ltd.) <<p.w@semantechs.co.uk>>

Application modules
-------

The EIC platform is composed of 4 application modules :

- [EIC Case Tracker](./cctracker/README.md)
- [EIC Coach Match](./ccmatch/README.md)
- [EIC SME Dashboard](./cockpit/README.md)
- [EIC Poll](./poll/README.md)

and of 6 library or framework modules :

- [oppidum](https://github.com/ssire/oppidum) : an XQuery web application framework for eXist-db
- [EIC Legacy XQuery Content Management Library](./xcm/README.md)
- [EIC XQuery Content Management Framework (excm)](./excm/README.md)
- [EIC XML front-end framework](./exfront/README.md)
- [EIC Platform Configuration](./platform/README.md)
- [EIC Taxonomies](./taxonomies/README.md)

and actually there is a 5th application module, the EIC Project Officer Dashboard (POD) which is not part of this publication. 

Licenses
-------

The oppidum module is released as free software, under the terms of the LGPL license.

The EIC SME Dashboard module, EIC Poll application module and the other library and framework modules are released as free software, under the terms of the European Union Public Licence [EUPL](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12).

For historical reasons some parts of the EIC Case Tracker and of the EIC Coach Match module may be subject to intellectual property restrictions, all the other parts beeing licensed with the European Union Public Licence [EUPL](https://joinup.ec.europa.eu/collection/eupl/eupl-text-11-12). Please consult us for more information about these specific components.

Installation
-------

The code published in this depot uses the [EU Login](https://ecas.ec.europa.eu/cas/about.html) European Commission's user authentication service. You can simulate this login in development mode but not in test or production mode. 

The code published in this depot is a snapshot of the individual depots used to deploy the Case Tracker, Coach Match, Poll and SME Dashboard application modules. Each application must actually run in its own database environment, so you need to make 4 different application installations if you want to deploy the full platform. Each application module requires only a subset of all the modules as explained in its README file. There is not yet a single installation script allowing to pick up some modules for an installation. We are working on that.

If you are interested by deploying a similar platform and need assistance, contact us at <EASME-SME-HELPDESK@ec.europa.eu>. Please add the "[EIC Platform]" keyword in the subject line.

Compatibility
-------

EIC Platform runs inside eXist-DB installed on Linux or Mac OS X environments only. The Windows environment is not yet supported. This requires some adaptations to the Oppidum framework amongst which to generate file paths with the file separator for Windows.
