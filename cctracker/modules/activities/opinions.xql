xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Composite CRUD controller to manage Opinions document into Activity workflow.

   Sub-documents : KAM-Opinion, ServiceHeadOpinion, SME-Opinion

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $case as element(), $activity as element(), $submitted as element() ) as element()* {
  let $errors := (
    )
  return $errors
};

(: ======================================================================
   Utility function to generate an notification model from existing 
   data or to generate an empty one for display
   See also: cases/information.xql
   ======================================================================
:)declare function local:gen-notification( $tag as xs:string, $contract as element()? ) {
  if ($contract/*[local-name(.) eq $tag ]) then 
    misc:unreference($contract/*[local-name(.) eq $tag ])
  else
    element { $tag }
      {
      <Date>not sent</Date>
      }
};
(: ======================================================================
   Generates a new composite document to write for the first time from submitted and legacy data
   NOTE: composite Opinions is not timestamped since each opinion is timestamped inside
   ======================================================================
:)
declare function local:bootstrap-document-with( $activity as element(), $submitted as element() ) {
  <Opinions>
   { $submitted }
  </Opinions>
};

(: ======================================================================
   Generates a new document to write from submitted and legacy data
   ======================================================================
:)
declare function local:gen-opinion-for-writing( $activity as element(), $submitted as element(), $root as xs:string ) {
  element { $root } {
    $submitted/(YesNoScaleRef | PositionRef | DecisionRef | Comment),
    misc:gen-current-person-name('Author'),
    misc:gen-current-date('Date')
    (: FIXME: no need for _Display :)
  }
};

(: ======================================================================
   Updates Information document inside Case
   ======================================================================
:)
declare function local:save-opinion( $activity as element(), $submitted as element(), $root as xs:string, $lang as xs:string ) {
  let $data := local:gen-opinion-for-writing($activity, $submitted, $root)
  let $opinions := $activity/Opinions
  return
    if ($opinions) then
      misc:save-content($opinions, $opinions/*[local-name(.) eq $root], $data)
    else
      let $opinions := local:bootstrap-document-with($activity, $data)
      return (
        update insert $opinions into $activity,
        ajax:report-success('ACTION-UPDATE-SUCCESS', ())
        )
};

(: ======================================================================
   Returns Information document model either for viewing or editing
   based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-document-for( $case as element(), $activity as element(), $goal as xs:string, $lang as xs:string ) as element() {
  let $data := $activity/Opinions
  return
    if ($data) then
      <Opinions>
        <Comments>{ $activity/FundingRequest/Comments/* }</Comments>
        { misc:unreference-person($activity/Assignment/ResponsibleCoachRef, 'ResponsibleCoach', $lang) }
        { misc:unreference($data/KAM-Opinion) }
        { misc:unreference($data/ServiceHeadOpinion) }
        { misc:unreference($data/SME-Opinion) }
        { local:gen-notification('SME-Notification', $data) }
      </Opinions>
    else (: lazy creation :)
      <Opinions>
        <Comments>{ $activity/FundingRequest/Comments/* }</Comments>
        { misc:unreference-person($activity/Assignment/ResponsibleCoachRef, 'ResponsibleCoach', $lang) }
        { local:gen-notification('SME-Notification', ()) }
      </Opinions>
};

(: ======================================================================
   Returns sub-opinion document model for goal
   ======================================================================
:)
declare function local:gen-opinion-for( $activity as element(), $root as xs:string, $goal as xs:string, $lang as xs:string ) as element() {
  let $data := $activity/Opinions/*[local-name(.) eq $root]
  return
    if ($data) then
      misc:unreference($data)
    else (: lazy creation :)
      element { $root } {(
        misc:gen-current-date('Date'),
        misc:gen-current-person-name('Author')
      )}
};

(: *** MAIN ENTRY POINT *** :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $case := $project/Cases/Case[No eq $case-no]
let $activity-no := tokenize($cmd/@trail,'/')[6]
let $activity := $case/Activities/Activity[No = $activity-no]
let $goal := request:get-parameter('goal', 'read')
let $resource-name := string($cmd/resource/@name)
let $root := if ($resource-name = 'opinions') then 'Opinions' else $resource-name (: composite controller :)
let $errors := access:pre-check-activity($project, $case, $activity, $m, $goal, $root)
return
  if (empty($errors)) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      let $errors := local:validate-submission($case, $activity, $submitted)
      return
        if (empty($errors)) then
          local:save-opinion($activity, $submitted, $root, $lang)
        else
          ajax:report-validation-errors($errors)
    else (: assumes GET :)
      if ($root = 'Opinions') then
        local:gen-document-for($case, $activity, $goal, $lang)
      else
        local:gen-opinion-for($activity, $root, $goal, $lang)
  else
    $errors
