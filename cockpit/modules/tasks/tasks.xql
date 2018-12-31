xquery version "3.0";
(: ------------------------------------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors: Franck Leplé <franck.leple@amplexor.com>

   Tasks library
   - Used to manipulated tasks collection (db/tasks/cockpit/<context>.xml 
      - <context> = community for instance
   - Access to tasks
   - Consume tasks
   - Add tasks

   July 2018 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)


import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace system = "http://exist-db.org/xquery/system";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../../xcm/modules/users/account.xqm";
import module namespace tasks = "http://oppidoc.com/ns/application/tasks" at "tasks.xqm";

(:
let $job-name := "Tasks-chron"
let $cron-expression := "0 * * ? * *"
let $xquery-resource := "/db/wwww/cockpit/modules/tasks/tasks.xql"
return
 scheduler:schedule-xquery-cron-job($xquery-resource, $cron-expression, $job-name),
 (:scheduler:delete-scheduled-job($job-name),:)
 scheduler:get-scheduled-jobs()
:)

(: 
  ===================================================================================================================== 
   *** ENTRY POINT ***
  =====================================================================================================================
:)  
system:as-user(account:get-secret-user(), account:get-secret-password(), tasks:task-trigger())
