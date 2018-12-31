Coach Match Configuration
=======

## Overview

Coach match application configuration is stored in XML resources in the _/db/www/ccmatch/config_ collection in database :

1. `mapping.xml` : mode attribute (_prod_ or _dev_) and base-url attribute to drive mode dependent URL generation (e.g. path to static resources)
2. `settings.xml` : application settings like mail server configuration for sending e-mails (contains the Sudoer credentials)
3. `services.xml` : third party services configuration to call services in other applications or to be called from other applications (contains the Surrogate credentials)

The `settings.xml` and `services.xml` resources must be uploaded manually for each installation, usually using the Java administration client, or you must use a platform depot.

## 1 First deployment

The path to the git folder containing the coach match application is called COACH-MATCH and should be equivalent to `EXIST-HOME/webapp/projects/ccmatch`

Always check `EXIST-HOME/client.properties` points to the correct port before proceeding. From this point you must have started your eXist-DB instance.

    cd COACH-MATCH/scripts
    ./install.sh {admin password}

then run the bootstrap deployment command (assuming port 7070) :

    ./init.sh {admin password}

For production environment, use `m=prod` (alt. dev, test), this will update `/db/www/ccmatch/config/mapping.xml` :

- line 1 : (for production) set `mode="prod" base-url="/"` attributes on the _site_ root element

That's it, you should be able to connect to coach match application (e.g. [http://localhost:7070/exist/projets/ccmatch]()) with the demo user (and any password) and from there create additional users from the _Manage users_ section. Note that you can also complete contact information and profile for the demo user.

If not using a platform depot :

1) edit `/db/www/ccmatch/config/settings.xml` :

- line 2 : set _SMTPServer_ to the address of your email SMTP server, start with _!_ if you do not really want to send e-mail (testing, etc.)
- line 3 : set _DefaultEmailSender_ to the e-mail address to appear as sender's e-mail address in some of Coach Match generated e-mails

2) edit `/db/www/ccmatch/config/services.xml` :

- line 7 : put the Case Tracker authorization token you want to import users from into the _AuthorizationToken_ element
- line 11 : put the Case Tracker coaches export services URL into the _URL_ element

3) create a secret user with DBA role in eXist-DB and store its name and password into your application settings as :

    <Sudoer>
      <User>dba user name</User>
      <Password>dba user password</Password>
    </Sudoer>

This is required for some management functions which must be executed with DBA role

4) create a secret user in the "users" group in eXist-DB and store its name and password into your application security settings as :

    <Surrogate>
      <User>_ecas_</User>
      <Password>user password</Password>
      <Groups>
        <Group>users</Group>
      </Groups>
    </Surrogate>

This is required to authentify users

## 2 Extra configuration

Create a `/db/debug` collection and create two empty resources :

- `login.xml` : containing an empty `<Login/>` root element
- `debug.xml` : containing an empty `<Debug/>` root element

The first one will keep track of login to your application (see `COACH-MATCH/models/login.xql`)

The second one will keep track of e-mail sent by the application, even if the e-mail server is disactivated with _!_ (see above)