xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Authors: Frédéric Dumonceaux <Frederic.DUMONCEAUX@ext.ec.europa.eu>
            Stéphane Sire <s.sire@opppidoc.fr>

   Job to generate and/or update reports

   Pre-conditions :
   - collection /db/sites/cctracker/report available and writable by guest
   - reports.xml loaded into application configuration collection

   Installation :
   a) add (adjust cron-trigger)
     <job type="user" xquery="/db/www/cctracker/modules/reports/job.xql" name="compute-reports" cron-trigger="0 30 4 * * ?" unschedule-on-exception="no">
       <parameter name="reports" value="all"/>
     </job>
     into exist/scheduler element of conf.xml
   b) deploy code into database (since jobs must be installed inside the database-
     curl -i "http://localhost:8080/exist/projects/cctracker/admin/deploy?pwd=[PASSWORD]&t=jobs[,policies]"

    See also :
    - "jobs" target in scripts/deploy.xql

   February 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace report = "http://oppidoc.com/ns/cctracker/reports" at "report.xqm";

(: Configuration from conf.xml :)
declare variable $local:reports external;

let $targets := if ($local:reports eq 'all') then fn:doc('/db/www/cctracker/config/reports.xml')//Report/string(@No) else $local:reports
return
  for $report in fn:doc('/db/www/cctracker/config/reports.xml')//Report[@No = $targets]
  let $cached := report:retrieve-report($report)
  return
    (report:run($report, $cached), true())[last()]
