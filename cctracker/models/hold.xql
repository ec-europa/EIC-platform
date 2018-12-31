xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utility to put login on Hold for maintenance

   SYNOPSIS (depending on mapping):
   - /admin/hold : query status
   - /admin/hold?toggle : toggle status (only same user can reverse hold)

   PRECONDITIONS:
   - $globals:log-file-uri MUST exists
   - allowed users are checked against Hold > Allow element(s) in $globals:settings-uri

   March 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";

declare variable $local:usage := 'Application not on Hold (use ?toggle to put it on hold, use ?toggle=1&amp;kickout=1 to put it on hold and kick out logged users), ?kickout to toggle kick out "on" or "off" while on hold';

(: ======================================================================
   Puts application on Hold 
   ======================================================================
:)
declare function local:hold( $user as xs:string, $logs as element(), $kickout as xs:boolean  ) as element() {
  let $ts := substring(string(current-dateTime()), 1, 19)
  return (
    update insert attribute { 'Hold' } { $user } into $logs,
    update insert attribute { 'KickOut' } { if ($kickout) then 'on' else 'off' } into $logs,
    update insert <Hold User="{$user}" TS="{$ts}">on</Hold> into $logs,
    oppidum:throw-message('INFO', concat('Application now on hold, kick out ', if ($kickout) then '"on"' else '"off"'))
    )
};

(: ======================================================================
   Returns application back to business
   ======================================================================
:)
declare function local:unhold( $user as xs:string, $logs as element()  ) as element() {
  let $ts := substring(string(current-dateTime()), 1, 19)
  return (
    update delete $logs/@Hold,
    update delete $logs/@KickOut,
    update insert <Hold User="{$user}" TS="{$ts}">off</Hold> into $logs,
    oppidum:throw-message('INFO', 'Application no more on hold')
    )
};


(: ======================================================================
   Sets @KickOut 'on' so that epilogue forces users to log out
   Returns current KickOut mode
   ======================================================================
:)
declare function local:toggleKickOut( $logs as element() ) as xs:string {
  let $ko := string($logs/@KickOut)
  return
    if ($ko eq 'on') then (
      update value $logs/@KickOut with 'off', 
      'off'
      )
    else if ($ko eq 'off') then (
      update value $logs/@KickOut with 'on',
      'on'
      )
    else
      $ko
};

let $user := oppidum:get-current-user()
let $toggle :=  'toggle' = request:get-parameter-names()
let $kickout :=  'kickout' = request:get-parameter-names()
return
  if ($user = fn:doc($globals:settings-uri)/Settings/Hold/Allow/text()) then (: authorized user :)
    if (doc-available($globals:log-file-uri)) then
      let $logs := fn:doc($globals:log-file-uri)/Logs
      return
        if ($toggle) then
          if ($logs/@Hold) then
            if ($logs/@Hold eq $user) then (: only same user can reset hold :)
              local:unhold($user, $logs)
            else
              let $msg := concat('Application already on hold by "', 
                                 string($logs/@Hold), '"', ', kick out ', if ($kickout) then '"on"' else '"off"' )
              return oppidum:throw-message('INFO', $msg)
          else if ($logs) then
            local:hold($user, $logs, $kickout)
          else
            oppidum:throw-error('DATA-NOT-FOUND', ())
        else
          let $ko := if ($kickout) then local:toggleKickOut($logs) else string($logs/@KickOut)
          let $msg := if ($logs/@Hold) then
                        concat('Application already on hold by "', string($logs/@Hold), '"', ', kick out "', $ko, '"')
                      else
                        $local:usage
          return oppidum:throw-message('INFO', $msg)
    else
      oppidum:throw-error('DOCUMENT-NOT-FOUND', ())
  else
    oppidum:throw-error('FORBIDDEN', ())
