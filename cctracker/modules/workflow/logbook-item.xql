xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Christine Vanoirbeek

   CRUD controller to manage logbook  
   It manages operations on the set and on single documents :
   - add-XXX to create a new document inside the set
   - update-XXX to update a document from the set
   - gen-XXX method to return document content for static display or editing
   where XXX is the document set key identifier (e.g. specialists).

   Note that if two persons edit the same document at the same time, as in a wiki
   the last saved version will be the definitive version.

   August 2013 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace mail = "http://exist-db.org/xquery/mail";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace activity = "http://platinn.ch/coaching/activity" at "../activities/activity.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "workflow.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Reports success with Location header to redirect to the Activity workflow page
   ======================================================================
:)
declare function local:report-success( $lang as xs:string, $activity as element() ) {
 
    let $item := $activity/Logbook/LogbookItem[last()] (: we need eXist node id, hence it must be retrieved from a stored document :)
    let $payload := workflow:gen-logbook-item-for-viewing($lang, $item, true()) (: true() because if u can create u can delete :)
    return
        ajax:report-success('ACTION-CREATE-SUCCESS', (), $payload)
};

(: ======================================================================
   Validates SpecialistRequestFunding submitted data. Returns "ok" if valid or a problem description
   TODO: - localize the description of the problem (lib/localize.xqm ?)
   ======================================================================
:)
declare function local:validate-logbook-item-submission( $data as element() ) as xs:string {
  let $valid := true()
  return "ok"
};

(: ======================================================================
   Reconstructs a SpecialistFundingRequest record from current data and from new submitted data
   Note that current data may be the empty sequence in case of creation.
   ======================================================================
:)
declare function local:gen-logbook-item-for-writing( $current as element()?, $new as element(), $index as xs:double? ) {
  let $uid := access:get-current-person-id ()
  return
  <LogbookItem>
    <Id>{$index}</Id>
    {$new/Date}
    {$new/CoachRef}
    {$new/NbOfHours}
    {$new/ExpenseAmount}
    {$new/Comment}
  </LogbookItem>
};

(: ===================
   Creates a new logbook item
   ===================
:)
declare function local:add-logbook-item( $activity as element(), $data as element(), $lang as xs:string ) as element()* {
  let $validation := local:validate-logbook-item-submission($data)
  return
    if ($validation = "ok") then
      if (empty($activity/Logbook)) then 
        let $save := local:gen-logbook-item-for-writing($activity, $data, 1)
        return
            (
            update insert <Logbook LastIndex="1">{$save}</Logbook> into $activity,
            local:report-success($lang, $activity)
            )
    
      else
        if ($activity/Logbook/@LastIndex castable as xs:integer) then
          let $index := number($activity/Logbook/@LastIndex) + 1
          let $save := local:gen-logbook-item-for-writing($activity, $data, $index)
          return
              (
              update value $activity/Logbook/@LastIndex with $index,
              update insert $save into $activity/Logbook,
              local:report-success($lang, $activity)
              )
        else
          oppidum:throw-error("DB-INDEX-NOT-FOUND", ())
    else
      oppidum:throw-error("SPECIALIST-VALIDATION-ERROR", $validation)
};

(: ======================================================================
   Computes a Costs element to be inserted into final report financial statements
   ======================================================================
:)
declare function local:gen-logbook-item-for-import( $activity as element() ) {
  let $coaches := distinct-values ($activity/Logbook/LogbookItem/CoachRef)
  let $approved-amount := $activity/FundingDecision/TotalFundingSources/TotalApproved/text()
  return
    <Costs>
      <CoachingHourlyRate>150</CoachingHourlyRate>
        {
        (: WARNING : do not return <CoachingCosts/> to be compatible with XTiger empty repetition model ! :)
        if (count($coaches) > 0) then
          <CoachingCosts>
          {
          for $c in $coaches
          return
            <CoachActivity>
             {$activity/Logbook/LogbookItem[CoachRef=$c][1]/CoachRef}
             <EffectiveNbOfHours>{sum($activity/Logbook/LogbookItem[CoachRef=$c]/NbOfHours)} </EffectiveNbOfHours>
             <EffectiveHoursAmount>{sum($activity/Logbook/LogbookItem[CoachRef=$c]/NbOfHours) * 150}</EffectiveHoursAmount>
             <EffectiveOtherExpensesAmount>{sum($activity/Logbook/LogbookItem[CoachRef=$c]/ExpenseAmount)}</EffectiveOtherExpensesAmount>
             <ActivityAmount>
               {sum($activity/Logbook/LogbookItem[CoachRef=$c]/NbOfHours) * 150 + sum($activity/Logbook/LogbookItem[CoachRef=$c]/ExpenseAmount)}
             </ActivityAmount>
            </CoachActivity>
          }
         </CoachingCosts>
         else
          ()
        }
      <TotalEffectiveCosts>
         <TotalEffectiveHoursNb>
           {sum($activity/Logbook/LogbookItem/NbOfHours)}
         </TotalEffectiveHoursNb>
         <TotalEffectiveHoursAmount>
           {sum($activity/Logbook/LogbookItem/NbOfHours) * 150}
         </TotalEffectiveHoursAmount>
         <TotalEffectiveOtherExpensesAmount>
           {sum($activity/Logbook/LogbookItem/ExpenseAmount)}
         </TotalEffectiveOtherExpensesAmount>
         <TotalActivityAmount>
            {sum($activity/Logbook/LogbookItem/NbOfHours) * 150 + sum($activity/Logbook/LogbookItem/ExpenseAmount)}
         </TotalActivityAmount>
       </TotalEffectiveCosts>
       <TotalApproved>{$approved-amount}</TotalApproved>
       <TotalBalance>
         {$approved-amount - sum($activity/Logbook/LogbookItem/NbOfHours) * 150 + sum($activity/Logbook/LogbookItem/ExpenseAmount)}
       </TotalBalance>
     </Costs>
};

(: ======================================================================
   Deletes the Logbook item with $id Id from the $activity
   ======================================================================
:)
declare function local:delete-logbook-entry( $activity as element(), $id as xs:string ) {
  if (access:check-logbook-update($activity)) then
    let $item := $activity/Logbook/LogbookItem[Id = $id]
    return
      if ($item) then (
        update delete $item,
        ajax:report-success('DELETE-LOGBOOKITEM-SUCCESS', ())
        )
      else
        oppidum:throw-error("URI-NOT-FOUND", ())
  else
    oppidum:throw-error("FORBIDDEN", ())
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $doc-id := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
let $case-no := tokenize($cmd/@trail, '/')[2]
let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
let $activity-no := tokenize($cmd/@trail, '/')[4]
let $activity := $case/Activities/Activity[No = $activity-no]
(: TODO: fine grain access control and generation of action buttons :)
return
  if ($case and $activity) then
    if ($m = 'DELETE' or (($m = 'POST') and (request:get-parameter('_delete', ()) eq "1"))) then (: real delete  :)
      local:delete-logbook-entry($activity, string($cmd/resource/@name))
    else if ($m = 'POST') then
      let $data := oppidum:get-data()
      return
        if (($doc-id = 'logbook') and access:check-logbook-update($activity)) then
          local:add-logbook-item($activity, $data, $lang)
        else
          oppidum:throw-error("FORBIDDEN", ())
    else (: assumes GET :)
      let $goal := request:get-parameter('goal', 'read')
      return
        if ($goal = 'import') then
          local:gen-logbook-item-for-import($activity)
        else
          <Logbook/>
  else
    oppidum:throw-error("URI-NOT-FOUND", ())
    
