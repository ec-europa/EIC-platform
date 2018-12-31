xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Simple CRUD controller to manage FinalReport document into Activity workflow.

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $case as element(), $activity as element(), $submitted as element() ) as element()* {
  if (string-length(normalize-space($submitted/ObjectivesAchievements/PositiveComment)) > 1000) then
    let $length := string-length(normalize-space($submitted/ObjectivesAchievements/PositiveComment))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary related to what has been achieved contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else if (string-length(normalize-space($submitted/ObjectivesAchievements/NegativeComment)) > 1000) then
    let $length := string-length(normalize-space($submitted/ObjectivesAchievements/NegativeComment))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary related to what has not been achieved contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else if (string-length(normalize-space($submitted/Comment)) > 1000) then
    let $length := string-length(normalize-space($submitted/Comment))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary related to the faced difficulties contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else if (string-length(normalize-space($submitted/PlannedContinuation)) > 1000) then
    let $length := string-length(normalize-space($submitted/PlannedContinuation))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary related to what remain to be done by the SME contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else if (string-length(normalize-space($submitted/Dissemination/Comment)) > 1000) then
    let $length := string-length(normalize-space($submitted/Dissemination/Comment))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary related to the attractiveness of this coaching contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else if (string-length(normalize-space($submitted/EvaluationCriteria/Business)) > 1000) then
    let $length := string-length(normalize-space($submitted/EvaluationCriteria/Business))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary related to the evaluation criteria contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else if (string-length(normalize-space($submitted/EvaluationCriteria/Capacity)) > 1000) then
    let $length := string-length(normalize-space($submitted/EvaluationCriteria/Capacity))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary related to the project evaluation contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else 
    ()
};

(: ======================================================================
   Generates a new document to write from submitted and legacy data
   ======================================================================
:)
declare function local:gen-document-for-writing( $case as element(), $activity as element(), $submitted as element() ) {
  <FinalReport LastModification="{ current-dateTime() }">
    {
    $submitted/*[not(local-name() = ('TimesheetFile','ObjectivesAchievements'))],
    element { 'ObjectivesAchievements' }
    {
      $submitted/ObjectivesAchievements/*[not(local-name() = 'TargetedMarkets')]
    }
    }
  </FinalReport>
};

(: ======================================================================
   Utility to replace a legacy node for nodes that contains a list of nodes
   e.g. TargetedMarkets > TargetedMarketRef
   TODO: factorize with same in needs-analysis.xql
   ======================================================================
:)
declare function local:update-node-list( $parent as element(), $legacy as element()?, $list as element()? ) {
  if (count($list/*) > 0) then
    if ($legacy) then
      if ( (every $x in $legacy/* satisfies some $y in $list/* satisfies $x/text() eq $y/text())
           and 
           (every $x in $list/* satisfies some $y in $legacy/* satisfies $x/text() eq $y/text()) ) then
         () (: no change :)
      else
        update replace $legacy with $list
    else
      update insert $list into $parent
  else
    ()
};

(: ======================================================================
   Updates the Stats fields directly inside the case information document
   ======================================================================
:)
declare function local:save-targeted-markets( $case as element(), $targeted-markets as element()? ) {
  let $e := $case/../../Information/Beneficiaries/(Coordinator | Partner)[PIC eq $case/PIC]
  return
    local:update-node-list($e, $e/TargetedMarkets, $targeted-markets)
};

(: ======================================================================
   Updates document inside Activity
   ======================================================================
:)
declare function local:save-document( $case as element(), $activity as element(), $submitted as element(), $lang as xs:string ) {
  let $data := local:gen-document-for-writing($case, $activity, $submitted)
  let $forward := 
    if ('submit' = request:get-parameter-names()) then 
      <forward command="autoexec">ae-advance</forward>
    else
      ()
  return
    (
    local:save-targeted-markets($case, $submitted/ObjectivesAchievements/TargetedMarkets),
    misc:save-content($activity, $activity/FinalReport, $data, $forward)
    )
};

(: ======================================================================
   Generates TimesheetFile element from  activity either for display or editing
   Note double feedback, one for 'constant' plugin and one for 'file' plugin
   ====================================================================== 
:)
declare function local:gen-timesheet( $activity ) as element()? {
  if ($activity/Resources/TimesheetFile) then
    let $stamp := string($activity/Resources/TimesheetFile/@Date)
    let $date := display:gen-display-date($stamp, 'en')
    let $time := concat(substring($stamp, 12, 2), ':', substring($stamp, 15, 2))
    let $feedback := concat('timesheet uploaded on ', $date, ' at ', $time)
    return
      <TimesheetFile _Display="{ $feedback }" data-input="{ $feedback }">
        { $activity/Resources/TimesheetFile/text() }
      </TimesheetFile>
  else 
    ()
};

declare function local:gen-targeted-market-ref( $case as element(), $goal as xs:string ) as element()? {
  let $e := $case/Information/ClientEnterprise
  return
    if ($e) then
      if ($goal eq 'read') then 
        misc:unreference($e/TargetedMarkets[TargetedMarketRef]) 
      else 
        $e/TargetedMarkets[TargetedMarketRef]
    else
      ()      
};

(: ======================================================================
   Returns document model either for viewing or editing based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-document-for( $case as element(), $activity as element(), $goal as xs:string, $lang as xs:string ) as element() {
  let $data := $activity/FinalReport
  return
    <FinalReport>
      {
      if ($data) then misc:unreference($data/*[not(local-name(.) = ('ObjectivesAchievements'))]) else (),
      element { 'ObjectivesAchievements' }
      {
        misc:unreference($data/ObjectivesAchievements/*),
        local:gen-targeted-market-ref($case, $goal)
      },
      local:gen-timesheet($activity) 
      }
    </FinalReport>
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
let $errors := access:pre-check-activity($project, $case, $activity, $m, $goal, 'FinalReport')
return
  if (empty($errors)) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      let $errors := local:validate-submission($case, $activity, $submitted)
      return
        if (empty($errors)) then
            local:save-document($case, $activity, $submitted, $lang)
        else
          ajax:report-validation-errors($errors)
    else (: assumes GET :)
      local:gen-document-for($case, $activity, $goal, $lang)
  else
    $errors
