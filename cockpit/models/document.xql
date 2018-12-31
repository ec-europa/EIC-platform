xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Generic CRUD controller to manage a document inside an Event application workflow

   Implements :
   - access control (using tab permissions in application.xml)
   - GET to return document XML data
   - POST (ajax protocol) to update document and eventually make a workflow transition 
     (with extra ?to and ?submit parameters)

   September 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../lib/template.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../xcm/lib/ajax.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../xcm/modules/workflow/workflow.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   NOTE: does nothing since real validation occurs when submitting
   ======================================================================
:)
declare function local:validate-submission( $form as element() ) as element()* {
  let $errors := (
    )
  return $errors
};

(: ======================================================================
   See also status.xql and workflow:pre-check-transition in xcm/workflow.xqm
   FIXME: implement data validation before transition (see status.xql) !
   ====================================================================== 
:)
declare function local:submit( $enterprise as element(), $event as element() ) {
  let $event-def := fn:collection($globals:events-uri)//Event[Id eq $event/Id]
  let $workflow := $event-def/Programme/@WorkflowId
  let $from := $event/StatusHistory/CurrentStatusRef/text()
  let $to := request:get-parameter('to', $event/StatusHistory/CurrentStatusRef/text() + 1)
  let $transition := fn:filter( workflow:get-transition-for($workflow, $from, $to), function ($t) { access:check-status-change($t, $enterprise, $event) } )
  return
    if (not($transition)) then
      ajax:throw-error('WFSTATUS-NO-TRANSITION', ())
    (: DEPRECATED :)
    (:else if (not(access:check-status-change($transition, $enterprise, $event))) then
      ajax:throw-error('WFSTATUS-NOT-ALLOWED', ()):)
    else
    (: FIXME: picks up only 1st transition, filtering out TriggerBy transition when possible 
              because it seems fn:filter does not preserve document order :)
      let $elected := (if (some $t in $transition satisfies not($t/@TriggerBy)) then $transition[not(@TriggerBy)] else $transition)[1]
      return
        let $valid := template:assert-event-transition($elected, $event-def, $event, $enterprise)
        return
          if (local-name($valid) eq 'valid') then
            let $update := workflow:apply-transition-to($elected/@To, $event, ())
            return
              if (local-name($update) ne 'error') then
                let $notify := workflow:apply-notification($workflow, <success/>, $elected, $enterprise, $event)
                let $msg := if ($elected/@Message) then string($elected/@Message) else "WFSTATUS-UPDATED"
                return
                  ajax:report-success-redirect($msg, (), $event/Id)
              else
                $update
          else
            $valid
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $document := request:get-attribute('xquery.document')
(: FIXME: we may need to a more specific document name if event dependent, 
   actually only the validation template is configured either from application.xml 
   or from the event meta data :)
let $tokens := tokenize($cmd/@trail, '/')
let $enterprise-no := $tokens[2]
let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $enterprise-no]
let $event-no := $tokens[4]
let $event-application := $enterprise//Event[Id eq $event-no]
let $goal := if ($m = 'POST') then 'update' else 'read'
let $access := access:get-tab-permissions($goal, $document, $enterprise, $event-application)
return
  (: FIXME: access:check-workflow-permissions ? :)
  if (local-name($access) eq 'allow') then
    if ($m = 'POST') then
      let $form := oppidum:get-data()
      let $errors := local:validate-submission($form)
      return
        if (empty($errors)) then
          let $saved :=  template:update-resource-id($document, $event-no, $enterprise, $event-application, $form)
          return
            if (local-name($saved) eq 'success' and ('submit' = request:get-parameter-names())) then
              local:submit($enterprise, $event-application)
            else
              $saved
        else
          ajax:report-validation-errors($errors)
    else (: assumes GET :)
      template:gen-read-model($document, $enterprise, $event-application, $lang)
  else
    $access
