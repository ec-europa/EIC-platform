xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Job to periodically compute and manage alerts

   DEPRECATED and REMOVED from scheduler since EU Login / exist-2.2 see SMEIMNT-300

   Currently clean up dangling accounts (i.e interrupted registrations
   that didn't lead to login creation)

   The dangling-interval parameter defines as an xs:dayTimeDuration the minimal 
   duration above which dangling accounts are removed

   Pre-conditions :
   - collection $globals:histories-uri (/db/sites/ccmatch/histories) available
   - access rights rwurwurwu on $globals:checks-uri so that guest can add files into it

   Installation :
   a) add (adjust cron-trigger)
     <job type="user" xquery="/db/www/ccmatch/modules/alerts/job.xql" name="cleanup-accounts" cron-trigger="0 30 4 * * ?" unschedule-on-exception="no">
       <parameter name="dangling-interval" value="PT60M"/>
     </job>
     into exist/scheduler element of conf.xml
   b) deploy code into database (since jobs must be installed inside the database-
     curl -i "http://localhost:8080/exist/projets/ccmatch/admin/deploy?pwd=[PASSWORD]&t=jobs[,policies]"
  
   Test :
   - you can use this cron expression (every 5 minutes) :  cron-trigger="0 0/5 * * * ?"

    See also :
    - "jobs" target in scripts/deploy.xql

   TODO:
   - clean up tourist coaches (i.e. coaches that never asked for an acceptance)
   - check what happens if deleting an acount while user is creating it (?)

   July 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace system = "http://exist-db.org/xquery/system";

import module namespace account = "http://oppidoc.com/ns/account" at "../users/account.xqm";
import module namespace check = "http://oppidoc.com/ns/alert/check" at "check.xqm";
import module namespace histories = "http://oppidoc.com/ns/histories" at "../../lib/histories.xqm";

(: Configuration from conf.xml :)
declare variable $local:dangling-interval external;
declare variable $local:noaccredite-interval := "PT31D";

let $threshold1 := xs:dayTimeDuration($local:dangling-interval)
(:let $threshold2 := xs:dayTimeDuration($local:noaccredite-interval):)
return
  system:as-user(account:get-secret-user(), account:get-secret-password(),
    histories:archive-all (
      'alerts', 
      (
        check:remove-dangling-account($threshold1)(:,
        check:remove-account-without-submission($threshold1):)
      )
    )
  )
