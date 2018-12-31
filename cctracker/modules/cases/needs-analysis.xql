xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage NeedsAnalysis document either into Case 
   or to serve dead copy inside Activity

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Very first initialization of the FinalReportApproval model
   ====================================================================== 
:)
declare function local:bootstrap-final-report( $activity as element()) {
  let $report := $activity/FinalReportApproval
  return
    if ($report) then
      $report
    else
      update insert <FinalReportApproval/> into $activity
};

(: ======================================================================
   Returns a forward element to include in Ajax response
   FIXME: hard coded status, l14n
   ======================================================================
:)
declare function local:gen-forward-notification( $case as element(), $data as element() ) as element()* {
  if ((count($case/Activities/Activity) = 0) and access:assert-transition($case, '3', '-1', $data)) then
    (
    <forward command="autoexec">ae-advance</forward>,
    <confirmation>Do you want to create a coaching activity and assign a coach now ?</confirmation>
    )
  else 
    ()
};

(: ======================================================================
   Returns Stats block by making an enterprise database lookup
   ======================================================================
:)
declare function local:gen-stats( $case as element(), $needs-analysis as element()?, $goal as xs:string ) as element()? {
  let $project := $case/../..
  let $e := $project/Information/Beneficiaries/(Coordinator|Partner)[PIC eq $case/PIC]
  return
    if ($e) then
      <Stats>
        {(
        $e/CreationYear,
        if ($goal eq 'read') then 
          misc:unreference(($e/(SizeRef | DomainActivityRef | TargetedMarkets[TargetedMarketRef]), $needs-analysis/Stats/SectorGroupRef)) 
        else 
          ($e/(SizeRef | DomainActivityRef | TargetedMarkets[TargetedMarketRef]), $needs-analysis/Stats/SectorGroupRef)
        )}
      </Stats>
    else
      ()
};

(: ======================================================================
   Utility to replace a legacy node 
   DECISION: Does not replace nor remove the legacy one if the new one is empty
   ======================================================================
:)
declare function local:update-node( $parent as element(), $legacy as element()?, $node as element()? ) {
  if ($node[. ne '']) then
    if ($legacy) then
      if (string($legacy) ne $node/text()) then 
        update value $legacy with $node/text()
      else
        ()
    else
      update insert $node into $parent
  else
    ()
};

(: ======================================================================
   Utility same as above but for nodes that contains a list of nodes
   e.g. TargetedMarkets > TargetedMarketRef
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
declare function local:save-stats( $case as element(), $stats as element()? ) {
  let $project := $case/../..
  let $e := $project/Information/Beneficiaries/(Coordinator|Partner)[PIC eq $case/PIC]
  return
    (
    local:update-node($e, $e/CreationYear, $stats/CreationYear),
    local:update-node($e, $e/SizeRef, $stats/SizeRef),
    local:update-node($e, $e/DomainActivityRef, $stats/DomainActivityRef),
    local:update-node-list($e, $e/TargetedMarkets, $stats/TargetedMarkets)
    )
};

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $submitted as element() ) as element()* {
  if (string-length(normalize-space(string-join($submitted/Context/Comments/Text, ' '))) > 1000) then
    let $length := string-length(normalize-space(string-join($submitted/Context/Comments/Text, ' ')))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary associated to the SME context contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else if (string-length(normalize-space(string-join($submitted/Comments/Text, ' '))) > 1000) then
    let $length := string-length(normalize-space(string-join($submitted/Comments/Text, ' ')))
    return
      oppidum:throw-error('CUSTOM', concat('The Challenges commentary contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else if (string-length(normalize-space(string-join($submitted/OverviewProgress/Text, ' '))) > 1000) then
    let $length := string-length(normalize-space(string-join($submitted/OverviewProgress/Text, ' ')))
    return
      oppidum:throw-error('CUSTOM', concat('The commentary associated to the progress notes contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else
    ()
};

declare function local:gen-information-for-writing( $submitted as element(), $case as element() ) {
  <NeedsAnalysis LastModification="{ current-dateTime() }">
    {(
      $submitted/(Contact | ContactPerson | Analysis | Tools),
      if ($submitted/Stats/SectorGroupRef) then
        <Stats>{ $submitted/Stats/SectorGroupRef }</Stats>
      else
        (),
      $submitted/(Context | Impact | Comments | OverviewProgress)
    )}
  </NeedsAnalysis>
};

(: ======================================================================
   Updates Information document inside Case
   ======================================================================
:)
declare function local:save-information( $lang as xs:string, $submitted as element(), $case as element() ) {
  let $found := $case/NeedsAnalysis
  let $data := local:gen-information-for-writing($submitted, $case)
  let $forward := local:gen-forward-notification($case, $data)
  return
    (
      if ($found) then (
        update replace $found with $data,
        local:save-stats($case, $submitted/Stats),
        ajax:report-success('ACTION-UPDATE-SUCCESS', (), (), $forward)
      ) else (
        update insert $data into $case,
        local:save-stats($case, $submitted/Stats),
        ajax:report-success('ACTION-CREATE-SUCCESS', (), (), $forward)
      ),
      misc:record-proxy($case, $submitted/KAMReportNAProxy),
      for $a in $case/Activities/Activity
      return misc:save-proxy($a, $submitted/KAMReportNAProxy)
    )[last()]
};

(: ======================================================================
   Returns Information document model either for viewing or editing goal
   ======================================================================
:)
declare function local:gen-information-for( $goal as xs:string, $container as element(), $lang as xs:string ) as element() {
  let $data := $container/NeedsAnalysis
  let $case := if (local-name($container) eq 'Case') then $container else $container/ancestor::Case
  return
    if ($data) then
      <NeedsAnalysis>
        { misc:unreference($data/*[local-name(.) ne 'Stats']) }
        { local:gen-stats($case, $data, $goal) }
        { misc:read-proxy-cache($case,'KAMReportNAProxy') }
      </NeedsAnalysis>
    else (: lazy creation - assumes container is Case :)
      <NeedsAnalysis>
        { $container/Information/ContactPerson }
        { local:gen-stats($case, $data, $goal) }
      </NeedsAnalysis>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $goal := request:get-parameter('goal', 'read')
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $case := $project/Cases/Case[No eq $case-no]
let $errors := access:pre-check-case($project, $case, $m, $goal, 'NeedsAnalysis')
return
  if (empty($errors)) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      let $errors := local:validate-submission($submitted)
      return
        if (empty($errors)) then
            local:save-information($lang, $submitted, $case)
        else
          ajax:report-validation-errors($errors)
    else if (contains($cmd/@trail, '/activities')) then  (: assumes GET on Activity needs analysis dead copy :) 
      let $activity-no := tokenize($cmd/@trail, '/')[6] 
      let $activity := if ($activity-no) then $case/Activities/Activity[No eq $activity-no] else ()
      return
        if ($activity) then
          (: we could send needs analysis dead copy however we keep showing the live copy :)
          local:gen-information-for(request:get-parameter('goal', 'read'), $case, $lang)
        else
          ajax:throw-error('ACTIVITY-NOT-FOUND', ())
    else (: assumes GET on Case needs analysis :) 
      local:gen-information-for(request:get-parameter('goal', 'read'), $case, $lang)
  else
    $errors
