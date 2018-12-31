xquery version "3.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Job to periodically pull evaluation feeds from hosts

   Pre-conditions :
   - collection $globals:histories-uri (/db/sites/ccmatch/histories) available
   - correct configuration of account:get-secret-user(), account:get-secret-password() in users/account.xqm
     so that job can write to $globals:histories-uri

   Installation :
   a) add (adjust cron-trigger)
     <job type="user" xquery="/db/www/ccmatch/modules/feeds/job.xql" name="pull-feeds" cron-trigger="0 45 4 * * ?" unschedule-on-exception="no">
     </job>
     into exist/scheduler element of conf.xml
   b) deploy code into database (since jobs must be installed inside the database-
     curl -i "http://localhost:7070/exist/projets/ccmatch/admin/deploy?pwd=[PASSWORD]&t=jobs[,policies]"
  
   Test :
   - you can use this cron expression (every 5 minutes) :  cron-trigger="0 0/5 * * * ?"

    See also :
    - "jobs" target in scripts/deploy.xql
    - test/feeds.xql for testing purpose

   FIXME: actually hard-coded host '1' !

   August 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace system = "http://exist-db.org/xquery/system";
import module namespace account = "http://oppidoc.com/ns/account" at "../users/account.xqm";
import module namespace feeds = "http://oppidoc.com/ns/feeds" at "feeds.xqm";
import module namespace histories = "http://oppidoc.com/ns/histories" at "../../lib/histories.xqm";

declare variable $local:algo external;

let $algorithm := if ($local:algo = ('reset', 'regenerate')) then $local:algo else 'regenerate'
return
  <Pull>
    {
    system:as-user(account:get-secret-user(), account:get-secret-password(),
      histories:archive-all (
        'feeds', 
        feeds:update-coach-feeds(
          feeds:make-feed-requests('1', (), (), $algorithm),
          '1',
          false()
        )[local-name(.) eq 'error' or error or (ok = ('updated', 'replaced', 'reset'))]
      )
    )
    }
  </Pull>
