xquery version "3.0";
(: --------------------------------------
   EXCM - Analytics module

   Analytics event controller

   Record events into associated Request (UUID)

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   Pre-conditions : 'analytics' target deployed

   October 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/globals" at "../../lib/globals.xqm";
import module namespace analytics = "http://oppidoc.com/ns/analytics" at "analytics.xqm";
import module namespace misc = "http://oppidoc.com/ns/miscellaneous" at "../../lib/misc.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Insert specific 'filter' action (keyboard filtering) in analytics Events
   ======================================================================
:)
declare function local:process-filter( $history as element()?, $target as xs:string, $action as xs:string, $value as xs:string, $count as xs:string) {
  if ($history and misc:assert-property('analytics', 'level', ('low', 'high'))) then
    update insert element { $target } {
      attribute MatchCount { $count },
      attribute { 'TS'} { current-dateTime() },
      attribute { 'Value' } { $value }
      } into $history/Events
  else
    ()
};

let $cmd := oppidum:get-command()
let $uuid := $cmd/resource/@name
let $action := request:get-parameter('action', 'unknown')
let $target := request:get-parameter('target', 'notarget')
let $value := request:get-parameter('value', 'novalue')
let $count := request:get-parameter('count', 'nocount')
return
    <Done>
    {
    if ($action eq 'filter') then
      let $history := globals:collection('analytics')//History[Request/UUID = $uuid][not(@Done)]
      return local:process-filter( $history, $target, $action, $value, $count)
    else
      analytics:record-event($uuid, $target, $action)
    }
    </Done>
