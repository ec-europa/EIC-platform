xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   GET Controller to list contracts per-user

   NOTES:
   - currently called from the funding-decision of an activity

   June 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare function local:gen-contracts( $coach-ref as xs:string? ) {
  <Contracts Coach="{display:gen-person-name($coach-ref, 'en')}" User="{ misc:gen-current-person-name() }" Date="{ substring(string(current-dateTime()), 1, 19) }">
  {
  for $contract in fn:collection($globals:projects-uri)//Activity[Assignment/ResponsibleCoachRef eq $coach-ref]//CoachContract
  let $model := $contract/*[1]
  let $activity := $contract/ancestor::Activity
  let $case := $contract/ancestor::Case
  return
    <Contract CaseNo="{$case/No}" ActivityNo="{$activity/No}" ProjectId="{$case/../../Id}">
      <Nature>{ local-name($model) }</Nature>
      { $contract/PoolNumber }
      { $model/Date }
      { $activity//TotalNbOfHours }
      { $case/../../Information/Acronym }
      { $case/../../Information/Call/PhaseRef }
      <SME>{ $case/../../Information/Beneficiaries/*[PIC eq $case/PIC]/Name/text() }</SME>
    </Contract>
  }
  </Contracts>
};

let $cmd := oppidum:get-command()
let $pid := tokenize($cmd/@trail, '/')[2]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $activity-no := tokenize($cmd/@trail, '/')[6]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case := $project/Cases/Case[No eq $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
let $errors := access:pre-check-activity($project, $case, $activity, 'GET', 'list', 'CoachContract')
return
  if (empty($errors)) then
    local:gen-contracts($activity/Assignment/ResponsibleCoachRef)
  else
    $errors
