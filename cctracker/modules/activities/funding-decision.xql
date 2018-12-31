xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Simple CRUD controller to manage FundingDecision document into Activity workflow.

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/check" at "../../lib/check.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../../lib/media.xqm";
import module namespace email = "http://oppidoc.com/ns/cctracker/mail" at "../../lib/mail.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "../workflow/alert.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Extracts the Contract signature date from the Case
   See also: management.xql
   ======================================================================
:)
declare function local:gen-grant-signature( $case as element() ) as element()? {
  if ($case/../../Information/Contract/Date[. ne '']) then
    <Contract>{ misc:unreference($case/../../Information/Contract/Date)}</Contract>
  else
    ()
};

(: ======================================================================
   Sends an Email to EASME coaching assistants once a coaching plan has been approved
   Returns the list of e-mail addresses of recipients
   TODO: use Email / Recipients model in application.xml to factorize
   ======================================================================
:)
declare function local:notify-coach-plan-approved( $case as element(), $activity as element() ) as xs:string* {
  let $from := media:gen-current-user-email(false())
  let $mail := email:render-email("coach-plan-approved", 'en', $case/../.., $case, $activity,
                <var name="Nb_Of_Hours">{ $activity/FundingRequest/Budget/Tasks/TotalNbOfHours/text() }</var>
                )
  return
    let $subject := $mail/Subject/text()
    let $content := media:message-to-plain-text($mail/Message)
    let $to := $mail/To/text()
    return
      if (check:is-email($to)) then
        if (media:send-email('action', $from, $to, $subject, $content)) then
          $to
        else
          concat($to, " (server error, message not sent)")
      else
        concat("'", $to, "' (malformed e-mail address, message not sent)")
};

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
   Generates a new document to write from submitted and legacy data
   ======================================================================
:)
declare function local:gen-document-for-writing( $legacy as element()?, $submitted as element() ) {
  <FundingDecision LastModification="{ current-dateTime() }">
    {(
    $submitted/(DecisionRef | Comment),
    misc:gen-current-person-name('Author'),
    <Date>{ current-dateTime() }</Date>,
    $legacy/CoachContract
    )}
  </FundingDecision>
};

(: ======================================================================
   Filters the Approval response in order to :
   - automatically send an (unarchived) notification message to EASME coaching assistants
   - add a forward element to the response to send "coach-contracting-start"
     notification e-mail message
   ======================================================================
:)
declare function local:filter-approval-response( 
  $response as element(),
  $approved as xs:boolean, 
  $case as element(), 
  $activity as element() 
  ) as element() 
{
  if ((local-name($response) eq 'success') and $approved) then
    let $feedback := local:notify-coach-plan-approved($case, $activity)
    return (: filters rewritten success message or default success message :)
      <success>
       {
       if (count($feedback) > 0) then (: rewrites success message :)
         let $res := oppidum:throw-message('COACH-PLAN-APPROVED-EMAIL', string-join($feedback, ', ')) 
         return $res/*
       else
         $response/*
       }
       <forward command="add">coach-contracting-start</forward>
      </success>
  else
    $response
};

(: ======================================================================
   Updates document inside Activity
   NOTE: uses hard-coded value '1' for DecisionRef value test
   ======================================================================
:)
declare function local:save-document( $case as element(), $activity as element(), $submitted as element(), $lang as xs:string ) {
  let $legacy := $activity/FundingDecision
  let $data := local:gen-document-for-writing($legacy, $submitted)
  let $approved := ($submitted/DecisionRef/text() eq '1') and (empty($legacy/DecisionRef) or ($legacy/DecisionRef/text() ne '1'))
  return
    local:filter-approval-response(
        misc:save-content($activity, $activity/FundingDecision, $data),
        $approved, $case, $activity)
};

(: ======================================================================
   Returns document model either for viewing or editing based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-document-for( $case as element(), $activity as element(), $goal as xs:string, $lang as xs:string ) as element() {
  let $data := $activity/FundingDecision
  let $coach-contract := local:gen-embedded-coach-contract($data/CoachContract)
  return
    <FundingDecision>
      { 
      if ($data/*[local-name(.) ne 'CoachContract']) then
        misc:unreference($data/*[local-name(.) ne 'CoachContract'])
      else if ($goal eq 'update') then (: first Approval editing :)
        ( 
        misc:gen-current-date('Date'),
        misc:gen-current-person-name('Author')
        )
      else
        (),
      if ($goal eq 'read') then (
        local:gen-grant-signature($case),
        $coach-contract
        )
      else 
        ()
      }
    </FundingDecision>
};

(: ======================================================================
   Generates a new composite document to write for the first time from submitted and legacy data
   ======================================================================
:)
declare function local:bootstrap-document-with( $activity as element(), $data as element() ) {
  <FundingDecision LastModification="{ current-dateTime() }">
   { $data }
  </FundingDecision>
};

(: ======================================================================
   Generates a new CoachContract to write from submitted and legacy data
   ======================================================================
:)
declare function local:gen-coach-contract-for-writing( $activity as element(), $submitted as element() ) {
  let $model := $submitted/(Contract | Amendment)
  return
    if ($model) then
      <CoachContract>
        {
        element { local-name($model) } {(
          $model/Date, 
          misc:gen-current-person-name('Author')
          )},
        $submitted/PoolNumber
        }
      </CoachContract>
    else
      ()
};

(: ======================================================================
   Updates CoachContract document inside FundingDecision inside Activity
   ======================================================================
:)
declare function local:save-coach-contract( $case as element(), $activity as element(), $submitted as element(), $lang as xs:string ) {
  let $data := local:gen-coach-contract-for-writing($activity, $submitted)
  let $host := $activity/FundingDecision
  return
    if ($host) then
      misc:save-content($host, $host/CoachContract, $data)
    else
      misc:save-content($activity, (), local:bootstrap-document-with($activity, $data))
};

(: ======================================================================
   Returns document model either for viewing or editing based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-coach-contract-for( $case as element(), $activity as element(), $goal as xs:string, $lang as xs:string ) as element() {
  let $data := $activity/FundingDecision/CoachContract
  return
    if ($data) then 
      misc:unreference($data)
    else (: lazy creation :)
      <CoachContract/>
};

declare function local:gen-embedded-coach-contract( $contract as element()? ) as element()? {
  <CoachContract>
    <Nature>{ local-name($contract/*[1]) }</Nature>
    { $contract/PoolNumber }
    { misc:unreference($contract/*/Date) }
    { misc:unreference($contract/*/Author) }
  </CoachContract>
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
let $root := if ($resource-name = 'funding-decision') then 'FundingDecision' else $resource-name (: composite controller :)
let $errors := access:pre-check-activity($project, $case, $activity, $m, $goal, $root)
return
  if (empty($errors)) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      let $errors := local:validate-submission($case, $activity, $submitted)
      return
        if ($root = 'FundingDecision') then
          local:save-document($case, $activity, $submitted, $lang)
        else if (empty($errors)) then
          local:save-coach-contract($case, $activity, $submitted, $lang)
        else
          ajax:report-validation-errors($errors)
    else (: assumes GET :)
      if ($root = 'FundingDecision') then
        local:gen-document-for($case, $activity, $goal, $lang)
      else
        local:gen-coach-contract-for($case, $activity, $goal, $lang)
  else
    $errors
