xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Job to test schedule alerts check computation

   Pre-conditions :
   - collection $globals:checks-uri (/db/sites/cctracker/checks) available
   - access rights rwxrwxrwx on $globals:checks-uri so that guest can add files into it

   Installation :
   a) add (adjust cron-trigger)
     <job type="user" xquery="/db/www/cctracker/modules/alerts/job.xql" name="check-alerts" cron-trigger="0 30 4 * * ?" unschedule-on-exception="no">
       <parameter name="checks" value="all"/>
     </job>
     into exist/scheduler element of conf.xml
   b) deploy code into database (since jobs must be installed inside the database-
     curl -i "http://localhost:8080/exist/projects/cctracker/admin/deploy?pwd=[PASSWORD]&t=jobs[,policies]"

    See also :
    - "jobs" target in scripts/deploy.xql

   July 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/alert/check" at "check.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";

(: Configuration from conf.xml :)
declare variable $local:task external; 
declare variable $local:checks external;
(:declare variable $local:checks:="8";:)

if ($local:task eq 'reminders') then
  (: FIXME: store credentials in settings in database and not in code ? :)
  system:as-user(account:get-secret-user(), account:get-secret-password(),
    check:archive-reminders(
      check:apply-reminders(
        for $check in fn:doc($globals:checks-config-uri)//Check
        return check:reminders-for-check($check)
      ),
      current-dateTime()
    )
  )
else (: defaults to 'alerts' :)
  if ($local:checks eq 'all') then
    for $check in fn:doc($globals:checks-config-uri)//Check[@No]
    return (check:cache-update($check, check:check($check)), true())[last()]
  else
    let $todo := tokenize($local:checks, ',')
    return
      if (exists($todo)) then
        for $check in fn:doc($globals:checks-config-uri)//Check[@No = $todo]
        return (check:cache-update($check, check:check($check)), true())[last()]
      else
        ()
