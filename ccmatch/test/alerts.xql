xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Test file for modules/alerts/job.xql periodical scheduled task

   Parameter:
- call with ?i=PT5M to manually set interval

   July 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace system = "http://exist-db.org/xquery/system";

import module namespace account = "http://oppidoc.com/ns/account" at "../modules/users/account.xqm";
import module namespace check = "http://oppidoc.com/ns/alert/check" at "../modules/alerts/check.xqm";
import module namespace histories = "http://oppidoc.com/ns/histories" at "../lib/histories.xqm";

(: Configuration from conf.xml :)
declare variable $local:dangling-interval := "PT10M";
declare variable $local:noaccredite-interval := "PT31D";

let $threshold1 := xs:dayTimeDuration(request:get-parameter('i', $local:dangling-interval))
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
