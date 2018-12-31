xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Changes Event application workflow status

   Returns either success with a Location header to redirect the page,
   or an error message

   Does not trigger e-mail editing window (always returns <done/> in Ajax response
   because application.xml does not define Recipients on any transition)

   See also equivalent function in CASE TRACKER

   August 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../../xcm/modules/workflow/workflow.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

declare function local:finish-status-change( $transition as element(), $enterprise as element(), $event-def as element(), $event-app as element() ) {
  if ($transition/@From eq '1' and $transition/@To eq "2") then
    if ($event-def/Rankings and not($event-def/Rankings//EnterpriseRef/text() = $enterprise/Id/text()) and not($event-def/FinalRankings)) then
      (
      update insert 
        <Applicant>
          <EnterpriseRef>{ $enterprise/Id/text() }</EnterpriseRef>
          <ProjectId Tag="Acronym">{ $enterprise/Events/Event[Id = $event-def/Id]//Data/Application//Acronym/text() }</ProjectId>
        </Applicant>
      into $event-def/Rankings//MainList
      )
    else
      ()
  else
    ()
  
};

(: MAIN ENTRY POINT :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq tokenize($cmd/@trail, '/')[2]]
let $event-def := fn:collection($globals:events-uri)//Event[Id eq tokenize($cmd/@trail, '/')[4]]
let $workflow := $event-def/Programme/@WorkflowId
let $event-application := $enterprise/Events/Event[Id = $event-def/Id]
let $transition := workflow:pre-check-transition($m, $workflow, $enterprise, $event-application)
return
  if (local-name($transition) eq 'error') then (: exit on error :)
    $transition
  else
    let $stop := () (: NOT USED : local:launch-services($transition, $case, $activity) - see CASE TRACKER if needed :)
    return
      if (exists($stop)) then (: exit on error :)
        $stop
      else (: validation using data template :)
        let $validation := template:assert-event-transition($transition, $event-def, $event-application, $enterprise)
        return
          if (local-name($validation) ne 'valid') then
            $validation
          else
            let $errors := workflow:apply-transition($transition, $enterprise, $event-application)
            return
              if ($errors) then
                $errors
              else
                (: TODO: use WFSTATUS-UPDATED when you complete workflow :)
                let $success := ajax:report-success-redirect(
                                  if ($transition/@Message) then 
                                    $transition/@Message
                                  else
                                    'WFSTATUS-UPDATED', 
                                  (),
                                  concat($cmd/@base-url, replace($cmd/@trail,'/status','')))
                return
                  (: TODO: implement local:finish-status-change($transition, $event-application, ()) if more side effects needed :)
                  let $post := local:finish-status-change($transition, $enterprise, $event-def, $event-application )
                  let $response := workflow:apply-notification($workflow, $success, $transition, $enterprise, $event-application)
                  (: e-mail messages are archived inside the Event (one Alerts history per Event) :)
                  return 
                    (: filters response to short-circuit notification if no recipients :)
                    if (empty($transition/Recipients) and empty($response/done)) then 
                      <success>
                        <done/>
                        { $response/* }
                      </success>
                    else
                      $response
