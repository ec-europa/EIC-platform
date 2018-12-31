xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Regenerates Alerts in all check caches (manual version)

   See also: job.xql (scheduled version of refresh.xql)

   June 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/alert/check" at "check.xqm";

declare option exist:serialize "method=html media-type=text/html";

<html>
  <body>
    <h1>Case Tracker alert caches refresh report</h1>
    <ul>
      {
      for $check in fn:doc(oppidum:path-to-config('checks.xml'))//Check
      let $res := check:cache-update($check, check:check($check))
      return <li>check #{string($check/@No)} done ({count($res/Case)} entries)</li>
      }
    </ul>
  </body>
</html>
