xquery version "1.0";
(: --------------------------------------
   SMEIMKT

   This is a sample script that can be run against the cctracker application.
   
   It lists the title of the cases w/o activities in the database.

   You can easily turn it into a migration script by applying database updates using XQuery update.

   Run it from you EXIST_HOME with:

   ./bin/client.sh -F webapp/projets/platform/migrations/sample.xql -u admin -P password -s

   or from the platform/env/migrations folder with :

   ../../../../../bin/client.sh -s -F sample.xql -u admin -P foo

   When running locally on a dev machine which has been started directly (no daemon) 
   you must remove the ../../../ path prefix in the module import statements.

   WARNING: since platform is a shared depot, be careful when you run this script 
   to open an ssh tunnel to the server that hosts the eXist-DB server instance 
   which contains the application to which this script applies (cctracker in this sample)
   -------------------------------------- :)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../../webapp/projets/cctracker/lib/globals.xqm";

<Output>
{
for $c in fn:collection($globals:cases-uri)//Case[empty(Activities/Activity)]
return
  $c/Information/Title
}
</Output>
