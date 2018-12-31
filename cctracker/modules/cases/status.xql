xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Cases Workflow Status controller.
   Manages POST submission to change workflow status.

   Returns either success with a Location header to redirect the page,
   or an error message.

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $case := $project/Cases/Case[No eq $case-no]
let $action := request:get-parameter('action', ())
let $argument := request:get-parameter('argument', 'nil')
let $from := request:get-parameter('from', "-1")
let $transition := workflow:pre-check-transition($m, 'Case', $project, $case, ())
return
  if (local-name($transition) eq 'error') then (: exit on error :)
    $transition
  (: TODO: implement @Launch protocol calling local:launch-services if needed :)
  else (: TODO: factorize with status.xql in activities from this point ? :)
    let $errors := workflow:apply-transition($transition, $project, $case, ())
    return
      if ($errors) then
        $errors
      else
        let $success := ajax:report-success-redirect('WFSTATUS-UPDATED', (), 
                          concat($cmd/@base-url, replace($cmd/@trail,'/status','')))
        return
          (: TODO: implement local:finish-status-change($transition, $case, $activity) if more side effects needed :)
          let $response := workflow:apply-notification('Case', $success, $transition, $project, $case, ())
          return 
            (: filters response to short-circuit notification if no recipients :)
            if (empty($transition/Recipients) and empty($response/done)) then 
              <success>
                <done/>
                { $response/* }
              </success>
            else
              $response
