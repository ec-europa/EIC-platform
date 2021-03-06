xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Activities Workflow Status controller.
   Manages POST submission to change workflow status.

   Returns either success with a Location header to redirect the page,
   or an error message

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "../workflow/alert.xqm";
import module namespace evaluation = "http://oppidoc.com/ns/cctracker/evaluation" at "evaluation.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

(: ======================================================================
   Launch external service before entering a new status
   Returns either an error if service could not be started, 
   otherwise returns the empty sequence
   This way services are configured via config/application.xml
   ======================================================================
:)
declare function local:launch-services( $transition as element(), $case as element(), $activity as element() ) as element()? {
  if ($transition/@Launch eq 'feedback-at-eval') then
    evaluation:launch-feedback($case, $activity, $transition/@Launch)
  else if ($transition/@Launch eq 'close-feedback-at-eval') then
    let $side-effect := evaluation:close-feedback($case, $activity, $transition/@Launch)
    return ()
  else ()
};

(: MAIN ENTRY POINT :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $pid := tokenize($cmd/@trail,'/')[2]
let $case-no := tokenize($cmd/@trail,'/')[4]
let $activity-no := tokenize($cmd/@trail,'/')[6]
let $project := fn:collection($globals:projects-uri)//Project[Id eq $pid]
let $case := $project/Cases/Case[No eq $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
let $transition := workflow:pre-check-transition($m, 'Activity', $project, $case, $activity)
return
  if (local-name($transition) eq 'error') then (: exit on error :)
    $transition
  else
    let $stop := local:launch-services($transition, $case, $activity)
    return
      if (exists($stop)) then (: exit on error :)
        $stop
      else (: TODO: factorize with status.xql in cases from this point ? :)         
        let $errors := workflow:apply-transition($transition, $project, $case, $activity)
        return
          if ($errors) then
            $errors
          else
            let $success := ajax:report-success-redirect('WFSTATUS-UPDATED', (), 
                              concat($cmd/@base-url, replace($cmd/@trail,'/status','')))
            return
              (: TODO: implement local:finish-status-change($transition, $case, $activity) if more side effects needed :)
              let $response := workflow:apply-notification('Activity', $success, $transition, $project, $case, $activity)
              return 
                (: filters response to short-circuit notification if no recipients :)
                if (empty($transition/Recipients) and empty($response/done)) then 
                  <success>
                    <done/>
                    { $response/* }
                  </success>
                else
                  $response
