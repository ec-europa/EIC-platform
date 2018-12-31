xquery version "3.0";
(: --------------------------------------
   EXCM - Analytics module

   Utilities

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   Pre-conditions : 'analytics' target deployed

   October 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace analytics = "http://oppidoc.com/ns/analytics";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/miscellaneous" at "../../lib/misc.xqm";

declare function local:zero( $n as xs:integer ) {
  if ($n ne 0) then
    concat('0', local:zero($n - 1))
  else
    ()
};

(: ======================================================================
   Add a History structure into user's histories to save current search
   request and to store forthcoming UI events in an Events container
   ======================================================================
:)
declare function local:do-save-request ( $request as element(), $history as element(), $histories as element() ) {
  let $uuid := $request//UUID
  let $redo :=
    if ($uuid and $histories//History[Request/UUID = $uuid]) then (: close previous query :)
      update insert attribute Done { '1' } into $histories//History[Request/UUID = $uuid]
    else
      ()
  return
    update insert $history into $histories
};

(: ======================================================================
   Implement search request response recording in analytics collection
   ======================================================================
:)
declare function local:save-request-imp (
  $host as xs:string?,
  $uid as xs:integer,
  $category as xs:string,
  $request as element()?,
  $sample-tag as xs:string?,
  $sample-max as xs:integer?,
  $response as element()*
  )
{
  let $log-level := misc:get-property('analytics', 'level')
  return
    if (globals:collection-available('analytics') and $log-level = ('low', 'high')) then
      try {
        let $analytics-uri := globals:collection-uri('analytics')
        let $bucket := floor($uid div 50)
        let $padded := concat(local:zero(4 - string-length(string($bucket))), $bucket)
        let $complete := if ($host) then concat($host, '/', $padded) else $padded
        let $coll := xmldb:create-collection($analytics-uri, $complete) (: lazy, TODO: permissions :)
        let $f := concat($analytics-uri, '/', $complete, '/', $uid, '.xml')
        let $history :=
          <History TS="{ util:system-dateTime() }" Purpose="{ $category }" Level="{ $log-level }">
            <Request>
              { misc:prune($request/*) }
            </Request>
            {
            if ($log-level eq 'high') then
              if ($sample-tag) then (: filter n-th first elements in XML fragment :)
                <Response Count="{count($response//*[local-name() eq $sample-tag])}">{ $response//*[local-name() eq $sample-tag][position() < $sample-max] }</Response>
              else  if ($sample-max) then (: filter n-th first elements in sequence :)
                <Response Count="{count($response)}">{ $response[position() < $sample-max] }</Response>
              else
                ()
            else
              ()
            }
            <Events/>
          </History>
        let $res :=
          if (doc-available($f)) then (: update of existing user analytics :)
            local:do-save-request($request, $history, fn:doc($f)/Histories)
          else (: lazy creation of user analytics :)
            xmldb:store(concat($analytics-uri, '/', $complete), concat($uid, '.xml'),
              <Histories>{ if ($host) then <Host>{ $host }</Host> else () }<Id>{ $uid }</Id>{ $history }</Histories>
              )
        return
          $response
      } catch * {
        misc:log-error(<error>Caught error {$err:code}: {$err:description}</error>),
        $response
      }
    else
      $response
};

(: ======================================================================
   Filter search request response and save it inside analytics collection
   attributing the request to current user Id
   ======================================================================
:)
declare function analytics:save-request (
  $category as xs:string,
  $request as element()?,
  $sample-tag as xs:string?,
  $sample-max as xs:integer?,
  $response as element()*
  )
{
  let $uid := globals:doc('persons')//Person[UserProfile/Remote = oppidum:get-current-user()]/Id
  return
    if ($uid) then
      local:save-request-imp((), $uid, $category, $request, $sample-tag, $sample-max, $response)
    else
      ()
};

(: ======================================================================
   Filter search request response and save it inside analytics collection
   if it contains an Analytics/UUID integer element
   Use the $host parameter to log web services requests coming from different
   applications / clients
   ======================================================================
:)
declare function analytics:save-request (
  $host as xs:string?,
  $category as xs:string,
  $request as element()?,
  $sample-tag as xs:string?,
  $sample-max as xs:integer?,
  $response as element()*
  )
{
  if ($request/Analytics/UID and $request/Analytics/UID castable as xs:integer) then
    let $uid := $request/Analytics/UID
    return
      local:save-request-imp($host, $uid, $category, $request, $sample-tag, $sample-max, $response)
  else
    $response
};

(: ======================================================================
   Record an event in the latest opened UUID request or do nothing if empty UUID
   ======================================================================
:)
declare function analytics:record-event( $uuid as xs:string?, $type as xs:string, $value as xs:string) {
  if ($uuid) then
    try {
      let $history := collection(globals:collection-uri('analytics'))//History[Request/UUID = $uuid][not(@Done)]
      return
        if ($history and misc:assert-property('analytics', 'level', ('low', 'high'))) then
          update insert element { $type } {
            attribute { 'TS' } { current-dateTime() },
            attribute { 'Value' } { $value }
            } into $history/Events
        else
          ()
    } catch * {
      ()
    }
  else
    ()
};
