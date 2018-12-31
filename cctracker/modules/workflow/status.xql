xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Workflow Status controller. 
   Manages POST submission to change workflow status. 

   Returns either success with a Location header to redirect the page,
   or an error message (cf docs/howto-crud.html).

   DEPRECATED

   TODO:
   - everything (check rights, change status, etc.)

   October 2013 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
(: 
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace activity = "http://platinn.ch/coaching/activity" at "../activities/activity.xqm";
:)

declare option exist:serialize "method=xml media-type=application/xml";

(: ======================================================================
   Closes a FinalReport by making a dead copy of ClientEnterprise 
   The test to create or update the dead copy is to handle workflow cycling,
   however it may be useless in current conditions
   ======================================================================
:)
declare function local:close-final-report ( $activity as element() ) {
  let $ce :=
    <ClientEnterprise>
      {
      fn:doc($globals:enterprises-uri)//Enterprise[Id = $activity/FundingRequest/ClientEnterprise/Enterprise/Id/text()]
      }
    </ClientEnterprise>
  return
    if ($activity/FinalReport/ClientEnterprise) then
      update replace $activity/FinalReport/ClientEnterprise with $ce
    else
      update insert $ce into $activity/FinalReport
};

(: ======================================================================
   Deletes FundingDecision document from the activity when the workflow 
   returns back to En préparation or En consultation status 
   This should be called from any status posterior to En consultation 
   ======================================================================
:)
declare function local:reset-funding-decision ( $activity as element() ) {
  let $fd := $activity/FundingDecision
  return
    if ($fd) then update delete $fd else ()
};

declare function local:write-activity-status( $activity as element(), $new-status as xs:string ) {
  let $history := $activity/StatusHistory
  let $previous := $history/PreviousStatusRef
  let $current := $history/CurrentStatusRef
  let $status-log := $history/Status[ValueRef = $new-status]
  return 
    if ($history) then (: sanity check :)
      (
      if ($previous) then 
        update value $previous with $current/text()
      else (: first lazy creation :)
        update insert <PreviousStatusRef>{$current/text()}</PreviousStatusRef> following $current,
      if ($current) then
        update value $current with $new-status
      else (: should not happen :)
        (),
      if (empty($status-log)) then
        let $log := 
          <Status>
            <Date>{substring(string(current-date()),1,10)}</Date>
            <ValueRef>{$new-status}</ValueRef>
          </Status>
        return
          update insert $log into $history
      else
        update replace $status-log/Date with <Date>{current-date()}</Date> 
      )
    else
      ()
};

let $m := request:get-method()
let $action := request:get-parameter('action', ())
let $argument := request:get-parameter('argument', ())
let $from := request:get-parameter('from', "-1")
let $cmd := oppidum:get-command()
let $case-no := tokenize($cmd/@trail, '/')[2]
let $activity-no := tokenize($cmd/@trail, '/')[4]
let $case := fn:collection($globals:cases-uri)/Case[No = $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
return
  if (($m = 'POST') and $activity) then
    let $cur := $activity/StatusHistory/CurrentStatusRef/text()
    return
      (: FIXME: for better security we should also check user has right to make this status change ! :)
      if ($from eq $cur) then (: sanity check :)
        if (not($cur castable as xs:decimal) or not($action = ('increment', 'decrement'))) then
          (: FIXME: call access:check-status-change(...)  :)
          

          ajax:throw-error('WFSTATUS-STATE-ERROR', $action)
        else 
          let $current-status := number($cur)
          let $new-status := if ($action = 'increment') then $current-status + number($argument) else $current-status - number($argument)
          return (
            local:write-activity-status($activity, string($new-status)),
            (: Hooks for side effects :)
            if ($new-status = 8) then local:close-final-report ($activity) else (),
            if (($new-status = (1,2)) and ($current-status >= 3)) then local:reset-funding-decision($activity) else (),
            ajax:report-success-redirect('WFSTATUS-UPDATED', (), concat($cmd/@base-url, replace($cmd/@trail,'/status','')))
            )
      else
        ajax:throw-error('WFSTATUS-FROM-ERROR', ())
  else
    ajax:throw-error('URI-NOT-SUPPORTED', ())
