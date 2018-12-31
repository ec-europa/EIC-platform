xquery version "3.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   Architecture:
   - local:enmap-XXX : turn XXX criteria into a map
   - local:filter-XXX : match a case or activity against XXX criteria map
       the sample will be serialized as JSON for plotting
   - stats:gen-cases / stats:gen-activities : main iterator functions to 
       apply criteria to all cases or activities and return matching samples
   - local:gen-ZZZ (caller script) : generate variables for case or activity sample

   January 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace stats = "http://oppidoc.com/ns/cctracker/stats";

declare namespace json="http://www.json.org";
declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";

declare variable $stats:weight-thresholds := ('2', '3');

(: ======================================================================
   Utility to generate a map entry iff value is defined
   ======================================================================
:)
declare function local:enmap( $name as xs:string, $value as item()* ) {
  if (exists($value)) then
    map:entry($name, $value)
  else
    ()
};

(: ======================================================================
   Return a map encoding Case related criteria
   ====================================================================== 
:)
declare function local:enmap-case( $cur as map(), $filter as element() ) as map() {
  let $user := oppidum:get-current-user()
  let $status := $filter//CaseStatusRef
  let $start-date := $filter/CaseStartDate/text()
  let $end-date := $filter/CaseEndDate/text()
  let $nuts := $filter//Nuts
  let $cie-on := if ($filter//Country or $filter//DomainActivityRef or $filter//TargetedMarketRef or $filter//SizeRef or $filter//CreationStartYear or $filter//CreationEndYear) then true() else ()
  return map:new((
    $cur,
    map:new((
      local:enmap(            'program', $filter//FundingProgramRef),
      local:enmap(              'phase', $filter//FundingPhaseRef),
      local:enmap(            'cut-off', $filter//ProgramCallRef),
      local:enmap(             'topics', $filter//TopicRef),
      local:enmap(            'officer', $filter//ProjectOfficerRef),
      local:enmap(             'status', $filter//CaseStatusRef),
      local:enmap(         'start-date', $filter/CaseStartDate),
      local:enmap(           'end-date', $filter/CaseEndDate),
      local:enmap(    'status-any-time', if ($start-date or $end-date) then () else $status),
      local:enmap(       'status-after', if ($start-date and not($end-date)) then if (empty($status)) then 1 to 10 else $status else ()),
      local:enmap(      'status-before', if ($end-date and not($start-date)) then if (empty($status)) then 1 to 10 else $status else ()),
      local:enmap(     'status-between', if ($start-date and $end-date) then if (empty($status)) then 1 to 10 else $status else ()),
      local:enmap(            'country', $filter//Country),
      local:enmap(               'nuts', $filter//Nuts),
      local:enmap(           'nuts-een', fn:collection($globals:regions-uri)//Region[NutsCodes/Nuts/text() = $nuts]/Id),
      local:enmap(             'domain', $filter//DomainActivityRef),
      local:enmap(             'market', $filter//TargetedMarketRef),
      local:enmap(               'size', $filter//SizeRef),
      local:enmap('creation-start-year', $filter//CreationStartYear),
      local:enmap(  'creation-end-year', $filter//CreationEndYear),
      local:enmap(                'een', stats:filter-region-criteria($user, $filter)),
      local:enmap(                'kam', stats:filter-kam-criteria($user, $filter)),
      local:enmap(       'sector-group', $filter//SectorGroupRef),
      local:enmap(       'init-context', $filter//InitialContextRef),
      local:enmap(     'target-context', $filter//TargetedContextRef),
      local:enmap(             'vector', $filter//VectorRef),
      local:enmap(               'idea', $filter//IdeaRef),
      local:enmap(           'resource', $filter//ResourceRef),
      local:enmap(            'partner', $filter//PartnerRef),
      local:enmap(             'cie-on', $cie-on)
      ))
    ))
};

(: ======================================================================
   Add Actvity related criteria to the $cur map of criteria
   ====================================================================== 
:)
declare function local:enmap-activity( $cur as map(), $filter as element() ) as map() {
  let $status := $filter//ActivityStatusRef
  let $start-date := $filter/ActivityStartDate
  let $end-date := $filter/ActivityEndDate
  return map:new((
    $cur,
    map:new((
      local:enmap(                   'coach', $filter//CoachRef),
      local:enmap(                 'service', $filter//ServiceRef),
      local:enmap(         'activity-status', $status),
      local:enmap(     'activity-start-date', $start-date),
      local:enmap(       'activity-end-date', $end-date),
      local:enmap('activity-status-any-time', if ($start-date or $end-date) then () else $status),
      local:enmap(   'activity-status-after', if ($start-date and not($end-date)) then if (empty($status)) then 1 to 11 else $status else ()),
      local:enmap(  'activity-status-before', if ($end-date and not($start-date)) then if (empty($status)) then 1 to 11 else $status else ()),
      local:enmap( 'activity-status-between', if ($start-date and $end-date) then if (empty($status)) then 1 to 11 else $status else ()),
      local:enmap(                'w-vector', stats:encode-needs-weight($filter, 'Vectors')),
      local:enmap(                  'w-idea', stats:encode-needs-weight($filter, 'Ideas')),
      local:enmap(              'w-resource', stats:encode-needs-weight($filter, 'Resources')),
      local:enmap(               'w-partner', stats:encode-needs-weight($filter, 'Partners')),
      local:enmap(          'cco-start-date', $filter/CoachContractingStartDate),
      local:enmap(            'cco-end-date', $filter/CoachContractingEndDate),
      local:enmap(           'ra-start-date', $filter/ReportApprovalStartDate),
      local:enmap(             'ra-end-date', $filter/ReportApprovalEndDate),
      local:enmap(          'sme-start-date', $filter/SMEFeedbackStartDate),
      local:enmap(            'sme-end-date', $filter/SMEFeedbackEndDate),
      local:enmap(            'coach-advice', $filter/CoachAdvices/CommunicationAdviceRef),
      local:enmap(              'kam-advice', $filter/KAMAdvices/CommunicationAdviceRef)
      ))
    ))
};

(: ======================================================================
   Add KPI related criteria to the $cur map of criteria
   ====================================================================== 
:)
declare function local:enmap-kpi( $cur as map(), $filter as element() ) as map() {
  let $kpi-scores := $filter/*[starts-with(local-name(.), 'KPI')][(Min ne '') or (Max ne '')]
  let $sf-scores := $filter/*[starts-with(local-name(.), 'SF')][(Min ne '') or (Max ne '')]
  (: note AdviceRef tag name MUST be limited to questions Q1-Q15 for XPath next line :)
  let $no-kpi := if (empty($kpi-scores) and empty($sf-scores) and empty($filter//AdviceRef)) then true() else ()
  let $no-feedbacks := if (empty($kpi-scores) and empty($sf-scores)) then true() else ()
  return
    map:new((
      $cur,
      map:new((
        local:enmap(      'kpi-scores', $kpi-scores),
        local:enmap('kpi-filter-names', for $s in $kpi-scores return local-name($s)),
        local:enmap(         'kpi-min', for $s in $kpi-scores return if ($s/Min) then number($s/Min) else 1),
        local:enmap(         'kpi-max', for $s in $kpi-scores return if ($s/Max) then number($s/Max) else 5),
        local:enmap(       'sf-scores', $sf-scores),
        local:enmap( 'sf-filter-names', for $s in $sf-scores return local-name($s)),
        local:enmap(          'sf-min', for $s in $sf-scores return if ($s/Min) then number($s/Min) else 1),
        local:enmap(          'sf-max', for $s in $sf-scores return if ($s/Max) then number($s/Max) else 5),
        local:enmap(              'q1', $filter/Q1/AdviceRef),
        local:enmap(              'q2', $filter/Q2/AdviceRef),
        local:enmap(              'q3', $filter/Q3/AdviceRef),
        local:enmap(              'q4', $filter/Q4/AdviceRef),
        local:enmap(              'q5', $filter/Q5/AdviceRef),
        local:enmap(              'q6', $filter/Q6/AdviceRef),
        local:enmap(              'q7', $filter/Q7/AdviceRef),
        local:enmap(              'q8', $filter/Q8/AdviceRef),
        local:enmap(              'q9', $filter/Q9/AdviceRef),
        local:enmap(             'q10', $filter/Q10/AdviceRef),
        local:enmap(             'q11', $filter/Q11/AdviceRef),
        local:enmap(             'q12', $filter/Q12/AdviceRef),
        local:enmap(             'q13', $filter/Q13/AdviceRef),
        local:enmap(             'q14', $filter/Q14/AdviceRef),
        local:enmap(             'q15', $filter/Q15/AdviceRef),
        local:enmap(          'no-kpi', $no-kpi),
        local:enmap(    'no-feedbacks', $no-feedbacks)
        ))
      ))
};

(: ======================================================================
   Implement filtering by Project related criteria
   Return true if project $p matches criteria in map $m.
   ====================================================================== 
:)
declare function local:filter-project( $m as map(), $p as element() ) {
      (not(map:contains($m, 'program')) or $p/Information/Call/FundingProgramRef = map:get($m, 'program'))
  and (not(map:contains($m,   'phase')) or $p/Information/Call/(SMEiFundingRef | FETActionRef) = map:get($m, 'phase'))
  and (not(map:contains($m, 'cut-off')) or $p/Information/Call/(SMEiCallRef|FTICallRef|FETCallRef) = map:get($m, 'cut-off'))
  (: TODO: and (empty($topics) or $p//TopicRef = $topics) :)
  and (not(map:contains($m, 'officer')) or $p/Information/ProjectOfficerRef = map:get($m, 'officer'))
};

(: ======================================================================
   Implement filtering by Case related criteria
   Return true if case $c matches criteria in map $m.
   ====================================================================== 
:)
declare function local:filter-case( $m as map(), $p as element(), $c as element() ) as xs:boolean {
  let $e := if (map:contains($m, 'cie-on')) then ($p/Information/Beneficiaries/*[PIC eq $c/PIC]) else ()
  return
    (: Case criteria filtering :)
    (not(map:contains($m, '           status-after')) or $c/StatusHistory/Status[./ValueRef = map:get($m, 'status-after')][./Date >= map:get($m, 'start-date')])
    and (not(map:contains($m,       'status-before')) or
       $c/StatusHistory/Status[./ValueRef = map:get($m, 'status-before')][./Date <= map:get($m, 'end-date')])
    and (not(map:contains($m,      'status-between')) or
       $c/StatusHistory/Status[./ValueRef = map:get($m, 'status-between')][./Date >= map:get($m, 'start-date') and ./Date <= map:get($m, 'end-date')])
    and (not(map:contains($m,     'status-any-time')) or $c[StatusHistory[CurrentStatusRef = map:get($m, 'status-any-time')]])
    (: SME criteria filtering :)
    and (not(map:contains($m,             'country')) or $e/Address/Country = map:get($m, 'country'))
    and (not(map:contains($m,                'nuts')) or $c/ManagingEntity/RegionalEntityRef = map:get($m, 'nuts-een'))
    and (not(map:contains($m,              'domain')) or $e/DomainActivityRef = map:get($m, 'domain'))
    and (not(map:contains($m,              'market')) or $e//TargetedMarketRef = map:get($m, 'market'))
    and (not(map:contains($m,                'size')) or $e/SizeRef = map:get($m, 'size'))
    and (not(map:contains($m, 'creation-start-year')) or $e/CreationYear >= map:get($m, 'creation-start-year'))
    and (not(map:contains($m,   'creation-end-year')) or $e/CreationYear <= map:get($m, 'creation-end-year'))
    (: EEN criteria filtering :)
    and (not(map:contains($m,                 'een')) or $c/ManagingEntity/RegionalEntityRef = map:get($m, 'een'))
    and (not(map:contains($m,                 'kam')) or $c/Management/AccountManagerRef = map:get($m, 'kam'))
    and (not(map:contains($m,        'sector-group')) or $c/NeedsAnalysis//SectorGroupRef = map:get($m, 'sector-group'))
    (: Life cycle context filtering :)
    and (not(map:contains($m,        'init-context')) or $c/NeedsAnalysis//InitialContextRef = map:get($m, 'init-context'))
    and (not(map:contains($m,      'target-context')) or $c/NeedsAnalysis//TargetedContextRef = map:get($m, 'target-context'))
    (: Business innovation needs :)
    and (not(map:contains($m,              'vector')) or $c/NeedsAnalysis//VectorRef = map:get($m, 'vector'))
    and (not(map:contains($m,                'idea')) or $c/NeedsAnalysis//IdeaRef = map:get($m, 'idea'))
    and (not(map:contains($m,            'resource')) or $c/NeedsAnalysis//ResourceRef = map:get($m, 'resource'))
    and (not(map:contains($m,             'partner')) or $c/NeedsAnalysis//PartnerRef = map:get($m, 'partner'))
};

(: ======================================================================
   Implement filtering by Activity related criteria
   Return true if activity $a matches criteria in map $m.
   ====================================================================== 
:)
declare function local:filter-activity( $m as map(), $a as element() ) as xs:boolean {
      (not(map:contains($m,                    'coach')) or $a//ResponsibleCoachRef = map:get($m, 'coach'))
  and (not(map:contains($m,                  'service')) or $a/Assignment/ServiceRef = map:get($m, 'service'))
  and (not(map:contains($m,    'activity-status-after')) or
      $a/StatusHistory/Status[./ValueRef = map:get($m, 'activity-status-after')][./Date >= map:get($m, 'activity-start-date')])
  and (not(map:contains($m,   'activity-status-before')) or
      $a/StatusHistory/Status[./ValueRef = map:get($m, 'activity-status-before')][./Date <= map:get($m, 'activity-end-date')])
  and (not(map:contains($m,  'activity-status-between')) or
      $a/StatusHistory/Status[./ValueRef = map:get($m, 'activity-status-between')][./Date >= map:get($m, 'activity-start-date') and ./Date <= map:get($m, 'activity-end-date')])
  and (not(map:contains($m, 'activity-status-any-time')) or $a[StatusHistory[CurrentStatusRef = map:get($m, 'activity-status-any-time')]])
  and (not(map:contains($m,                 'w-vector')) or $a//*[(local-name(.) = map:get($m, 'w-vector')) and (. = $stats:weight-thresholds)])
  and (not(map:contains($m,                   'w-idea')) or $a//*[(local-name(.) = map:get($m, 'w-idea')) and (. = $stats:weight-thresholds)])
  and (not(map:contains($m,               'w-resource')) or $a//*[(local-name(.) = map:get($m, 'w-resource')) and (. = $stats:weight-thresholds)])
  and (not(map:contains($m,                'w-partner')) or $a//*[(local-name(.) = map:get($m, 'w-partner')) and (. = $stats:weight-thresholds)])
  and (not(map:contains($m,           'cco-start-date')) or $a//CoachContract/Contract/Date >= map:get($m, 'cco-start-date'))
  and (not(map:contains($m,             'cco-end-date')) or $a//CoachContract/Contract/Date <= map:get($m, 'cco-end-date'))
  and (not(map:contains($m,            'ra-start-date')) or $a//CoachingManagerVisa/Date >= map:get($m, 'ra-start-date'))
  and (not(map:contains($m,              'ra-end-date')) or $a//CoachingManagerVisa/Date <= map:get($m, 'ra-end-date'))
  and (not(map:contains($m,           'sme-start-date')) or $a/StatusHistory/Status[ValueRef eq '11']/Date >= map:get($m, 'sme-start-date'))
  and (not(map:contains($m,             'sme-end-date')) or $a/StatusHistory/Status[ValueRef eq '11']/Date <= map:get($m, 'sme-end-date'))
  and (not(map:contains($m,             'coach-advice')) or $a/FinalReport//CommunicationAdviceRef = map:get($m, 'coach-advice'))
  and (not(map:contains($m,               'kam-advice')) or $a/FinalReportApproval//CommunicationAdviceRef = map:get($m, 'kam-advice'))
};

(: ======================================================================
   Implement filtering by KPI related criteria
   Return true if activity $a matches criteria in map $m.
   ====================================================================== 
:)
declare function local:filter-kpi( $m as map(), $a as element() ) {
  let $feedbacks := if (map:contains($m, 'no-feedbacks')) then () else stats:gen-feedbacks-sample($a)
  return
        (not(map:contains($m,         'q1')) or $a/FinalReportApproval/Recognition/RatingScaleRef = map:get($m, 'q1'))
    and (not(map:contains($m,         'q2')) or $a/FinalReportApproval/Tools/RatingScaleRef = map:get($m, 'q2'))
    and (not(map:contains($m,         'q3')) or $a/Evaluation//RatingScaleRef[@For eq 'SME1'] = map:get($m, 'q3'))
    and (not(map:contains($m,         'q4')) or $a/Evaluation//RatingScaleRef[@For eq 'SME2'] = map:get($m, 'q4'))
    and (not(map:contains($m,         'q5')) or $a/FinalReportApproval/Profiles/RatingScaleRef/text() = map:get($m, 'q5'))
    and (not(map:contains($m,         'q6')) or $a/Evaluation//RatingScaleRef[@For eq 'SME3'] = map:get($m, 'q6'))
    and (not(map:contains($m,         'q7')) or $a/FinalReport/KAMPreparation/RatingScaleRef = map:get($m, 'q7'))
    and (not(map:contains($m,         'q8')) or $a/FinalReport/ManagementTeam/RatingScaleRef = map:get($m, 'q8'))
    and (not(map:contains($m,         'q9')) or $a/Evaluation//RatingScaleRef[@For eq 'SME7'] = map:get($m, 'q9'))
    and (not(map:contains($m,        'q10')) or $a/FinalReport/Dissemination/RatingScaleRef = map:get($m, 'q10'))
    and (not(map:contains($m,        'q11')) or $a/Evaluation//RatingScaleRef[@For eq 'SME4'] = map:get($m, 'q11'))
    and (not(map:contains($m,        'q12')) or $a/FinalReport/ObjectivesAchievements/RatingScaleRef = map:get($m, 'q12'))
    and (not(map:contains($m,        'q13')) or $a/Evaluation//RatingScaleRef[@For eq 'SME5'] = map:get($m, 'q13'))
    and (not(map:contains($m,        'q14')) or $a/Evaluation//RatingScaleRef[@For eq 'SME6'] = map:get($m, 'q14'))
    and (not(map:contains($m,        'q15')) or $a/FinalReportApproval/Dialogue/RatingScaleRef = map:get($m, 'q15'))
    and (not(map:contains($m, 'kpi-scores')) or stats:check-min-max(map:get($m, 'kpi-filter-names'), map:get($m, 'kpi-min'), map:get($m, 'kpi-max'), $feedbacks))
    and (not(map:contains($m,  'sf-scores')) or stats:check-min-max(map:get($m, 'sf-filter-names'), map:get($m, 'sf-min'), map:get($m, 'sf-max'), $feedbacks))
};

(: ======================================================================
   CASE samples set generation matching $filter criteria
   The flags are string tokens that can be used to customize sample generation
   ======================================================================
:)
declare function stats:gen-cases ( $filter as element(), $flags as xs:string*, $lang as xs:string, $func ) as element()* {
  let $criteria := local:enmap-case(map:new(), $filter)
  (: Project filtering by call :)
  let $co-start-date := $filter/CutOffStartDate
  let $co-end-date := $filter/CutOffEndDate
  let $call-on := $co-start-date or $co-end-date
  (: cached map structure to speedup lookup :)
  let $cut-offs := if ($call-on) then stats:gen-cutoff-date-map() else ()
  return
    for $p in fn:collection($globals:projects-uri)/Project
    let $call-date := if ($call-on) then map:get($cut-offs, $p/Information/Call/(SMEiCallRef|FTICallRef|FETCallRef)) else ()
    where     (not($co-start-date) or $call-date >= $co-start-date)
          and (not($co-end-date) or $call-date <= $co-end-date)
          and local:filter-project($criteria, $p)
    return
      for $c in $p//Case
      where local:filter-case($criteria, $p, $c)
      return
        <Cases>{ $func($p, $c, $flags, $lang) }</Cases>
};

(: ======================================================================
   ACTIVITIES and KPI samples set generation matching $filter criteria
   The flags are string tokens that can be used to customize sample generation
   ======================================================================
:)
declare function stats:gen-activities ( $filter as element(), $flags as xs:string*, $lang as xs:string, $func ) as element()* {
  let $criteria := local:enmap-activity(
                     local:enmap-case(
                        if ($flags = 'kpi') then 
                          local:enmap-kpi(map:new(), $filter)
                        else 
                          map:new(map:entry('no-kpi', true())), $filter
                     ), $filter
                   )
  let $no-kpi := map:contains($criteria, 'no-kpi')
  (: Project filtering by call :)
  let $co-start-date := $filter/CutOffStartDate
  let $co-end-date := $filter/CutOffEndDate
  let $call-on := $co-start-date or $co-end-date
  (: Cached map structure to speedup lookup :)
  let $cut-offs := if ($call-on) then stats:gen-cutoff-date-map() else ()
  return
    for $p in fn:collection($globals:projects-uri)/Project
    let $call-date := if ($call-on) then map:get($cut-offs, $p/Information/Call/(SMEiCallRef|FTICallRef|FETCallRef)) else ()
    where     (not($co-start-date) or $call-date >= $co-start-date)
          and (not($co-end-date) or $call-date <= $co-end-date)
          and local:filter-project($criteria, $p)
    return
      for $c in $p//Case
      where local:filter-case($criteria, $p, $c)
      return
        for $a in $c//Activity
        where local:filter-activity($criteria, $a) and ($no-kpi or local:filter-kpi($criteria, $a))
        return
          <Activities>
            { $func($p, $c, $a, $flags, $lang) }
          </Activities>
};

(: ======================================================================
   Cache generator function
   ====================================================================== 
:)
declare function stats:gen-cutoff-date-map () as map() {
  map:new(
      (
      for $o in fn:doc('/db/sites/cctracker/global-information/programs.xml')/GlobalInformation/Description/Selector[@Name = ('FTICalls', 'FETCalls')]//Option
      return
          map:entry(
              $o/Code/text(),
              $o/Brief/text()
          ),
      for $o in fn:doc('/db/sites/cctracker/global-information/programs.xml')/GlobalInformation/Description/Selector[@Name eq 'SMEiCalls']//Option
      return
          map:entry(
              $o/Code/text(),
              string($o/Name/@Date)
          )
      )
  )
};

(: ======================================================================
   Generic cache generator function to merge several selectors into one
   Pre-condition: no Code overlapping, label coded as Brief or Name
   ====================================================================== 
:)
declare function stats:gen-selectors-map ( $selectors as xs:string* ) as map() {
  map:new(
      (
      for $o in fn:collection($globals:global-info-uri)/GlobalInformation/Description/Selector[@Name = $selectors]//Option
      return
          map:entry(
              $o/Code/text(),
              fn:head(($o/Brief/text(), $o/Name/text()))
          )
      )
  )
};

(: ======================================================================
   TODO: move to misc: ?
   ====================================================================== 
:)
declare function local:get-local-string( $lang as xs:string, $key as xs:string ) as xs:string {
  let $res := fn:doc($globals:dico-uri)/site:Dictionary/site:Translations[@lang = $lang]/site:Translation[@key = $key]/text()
  return
    if ($res) then
      $res
    else
      concat('missing [', $key, ', lang="', $lang, '"]')
};

declare function local:gen-values( $value as element()?, $literal as xs:boolean ) {
  <Values>
    {
    if ($literal) then 
      attribute { 'json:literal' } { 'true' }
    else
      (),
      $value/text()
    }
  </Values>
};

(: ======================================================================
   Generates code book for a Composition
   ====================================================================== 
:)
declare function stats:gen-composition-domain( $composition as element() ) as element()* {
  element { string($composition/@Name) }
  {
  for $m in $composition/Mean
  return
    <Labels>{ local:get-local-string('en', string($m/@loc)) }</Labels>,
  for $m in $composition/Mean
  return
    <Values>{ string($m/@Filter) }</Values>,
  for $m in $composition/Mean
  return
    <Legends>{ local:get-local-string('en', concat(string($m/@loc), '.legend')) }</Legends>
  }
};

(: ======================================================================
   Generates labels and values decoding book for a given selector name
   See also form:gen-selector-for in lib/form.xqm
   TODO: restrict to existing values in data set for some large sets (e.g. NOGA) ?
   FIXME: hard coded language parameter 'en'
   ====================================================================== 
:)
declare function stats:gen-selector-domain( $name as xs:string, $selector as xs:string, $literal as xs:boolean) as element()* {
  let $sel := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq $selector]
  return
    element { $name } {
      if ($sel/Group) then (: nested selector :)
        (
        for $v in $sel//Option
        let $concatWithId := starts-with($sel/@Label, 'V+')
        let $ltag := replace($sel/@Label, '^V\+', '')
        let $vtag := string($sel/@Value)
        return
          <Labels>
            { 
              if ($concatWithId) then
                concat($v/*[local-name(.) eq $vtag], ' - ', $v/*[local-name(.) eq $ltag])
              else
                $v/*[local-name(.) eq $ltag]/text()
            }
          </Labels>,
        for $v in $sel//Option
        let $tag := string($sel/@Value)
        return
          local:gen-values($v/*[local-name(.) eq $tag], $literal)
        )
      else (: flat selector :)
        (
        for $v in $sel/Option
        let $tag := string($sel/@Label)
        let $l := $v/*[local-name(.) eq $tag]/text()
        return
          <Labels>
            { 
            if (contains($l, "::")) then
              concat(replace($l, "::", " ("), ")")
            else 
              $l
            }
          </Labels>,
        for $v in $sel/Option
        let $tag := string($sel/@Value)
        return
          local:gen-values($v/*[local-name(.) eq $tag], $literal)
        )
    }
};

(: ======================================================================
   Stub to generates decoding books (labels, values) for a given selector
   ====================================================================== 
:)
declare function stats:gen-selector-domain( $name as xs:string, $selector as xs:string ) as element()* {
  stats:gen-selector-domain($name, $selector, false())
};

(: ======================================================================
   Generates decoding books (labels, values) for a given selector with 
   a specific format (i.e. literal)
   FIXME: same signature as homonym function ?
   ====================================================================== 
:)
declare function stats:gen-selector-domain( $name as xs:string, $selector as xs:string, $format as xs:string? ) as element()* {
  stats:gen-selector-domain($name, $selector, not(empty($format)) and ($format eq 'literal'))
};

(: ======================================================================
   Generates labels and values decoding book for a given selector name
   See also form:gen-selector-for in lib/form.xqm
   TODO: restrict to existing values in data set for some large sets (e.g. NOGA) ?
   FIXME: hard coded language parameter 'en'
   ====================================================================== 
:)
declare function stats:gen-selector-domain-regional-entities( $name as xs:string, $literal as xs:boolean) as element()* {
  let $sel := <Selector Name="RegionalEntities" Value="Id" Label="Label" Test="EEN Entities">{fn:collection($globals:regions-uri)/Region}</Selector>
  return
    element { $name } {
        (
        for $v in $sel/Region
        let $tag := string($sel/@Label)
        let $l := $v/*[local-name(.) eq $tag]/text()
        return
          <Labels>
            { 
            if (contains($l, "::")) then
              concat(replace($l, "::", " ("), ")")
            else 
              $l
            }
          </Labels>,
        for $v in $sel/Region
        let $tag := string($sel/@Value)
        return
          local:gen-values($v/*[local-name(.) eq $tag], $literal)
        )
    }
};

(: ======================================================================
   Generates decoding books (labels, values) for a regional entities
   ====================================================================== 
:)
declare function stats:gen-selector-domain-regional-entities( $name as xs:string) as element()* {
  stats:gen-selector-domain-regional-entities($name, false())
};


(: ======================================================================
   Generates labels and values decoding book for status of a given workflow name
   FIXME: hard coded language parameter 'en'
   ====================================================================== 
:)
declare function stats:gen-workflow-status-domain( $tag as xs:string, $name as xs:string ) as element()* {
  let $set := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']/WorkflowStatus[@Name eq $name]
  return
    element { $tag } {
      (
      for $v in $set/Status
      return
        <Labels>{ $v/Name/text() }</Labels>,
      for $v in $set/Status
      return
        <Values>{ $v/Id/text() }</Values>
      )
    }
};

(: ======================================================================
   Generates labels and values decoding book for a sequence of person's references
   This way the set can include persons who no longer hold the required role
   ======================================================================
:)
declare function stats:gen-persons-domain-for( $refs as xs:string*, $tag as xs:string ) as element()* {
  element { $tag }
    {
    (: Double FLWOR because of eXist 1.4.3 oddity see http://markmail.org/thread/mehfwoj6enc2z65v :)
    let $sorted := 
      for $p in fn:collection($globals:persons-uri)//Person[Id = $refs]
      order by $p/Name/LastName
      return $p
    return
      for $s in $sorted 
      return (
        <Labels>{ concat(normalize-space($s/Name/LastName), ' ', normalize-space($s/Name/FirstName)) }</Labels>,
        <Values>{ $s/Id/text() }</Values>
        )
    }
};

(: ======================================================================
   Generates years values for a sample set
   NOTE: Year tag name MUST BE consistent with stats.xml
   FIXME: could be directly computed client-side from the set (?)
   ======================================================================
:)
declare function stats:gen-year-domain( $set as element()* ) as element()* {
  for $y in distinct-values($set//Yr)
  where matches($y, "^\d{4}$")
  order by $y
  return
    <Yr>{ $y }</Yr>
};

(: ======================================================================
   Generates nuts values for a sample set
   NOTE: Nuts tag name consistent with stats.xml
   FIXME: could be directly computed client-side from the set (?)
   ======================================================================
:)
declare function stats:gen-nuts-domain( $set as element()* ) as element()* {
  for $y in distinct-values($set//Nuts)
  order by $y
  return
    <Nuts>{ $y }</Nuts>
};

(: ======================================================================
   Generates region values for a sample set
   NOTE: Region tag name consistent with stats.xml
   FIXME: could be directly computed client-side from the set (?)
   ======================================================================
:)
declare function stats:gen-regions-domain( $set as element()* ) as element()* {
  <EEN>
    {
    for $y in distinct-values($set//EEN)
    where $y ne ''
    order by $y
    return (
      <Labels>
        {
        if ($y ne '') then 
          display:gen-name-for-regional-entities( <t>{ $y }</t>, 'en')
        else 
          "undefined" 
        }
      </Labels>,
      <Values>{ $y }</Values>
      )
    }
  </EEN>
};

declare function stats:gen-cut-off-domain ( $set as element()* ) as element()* {
  let $cut-offs := stats:gen-cutoff-date-map () (: TOOD: map with screen value :)
  return
    <COf>
    {
    for $y in if ($set) then distinct-values($set//COf) else map:keys($cut-offs)
    where $y ne ''
    order by $y
    return (
      <Labels>{ map:get($cut-offs, $y) }</Labels>,
      <Values>{ $y }</Values>
      )
    }
    </COf>
};

declare function stats:gen-funding-phase-domain ( $set as element()* ) as element()* {
  <Ph>
    {
    let $set1 := stats:gen-selector-domain('Ph', 'SMEiFundings', ())
    let $set2 := stats:gen-selector-domain('Ph', 'FETActions', ())
    return (
      $set1/Labels,
      $set2/Labels,
      $set1/Values,
      $set2/Values
      )
    }
  </Ph>
};

(: ======================================================================
   Generates labels and values decoding book for case impact variable with name and id
   ====================================================================== 
:)
declare function stats:gen-case-vector( $name as xs:string, $id  as xs:string ) {
  let $set := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']//Section[Id eq $id]
  return
    element { $name } {
      (
      for $v in $set/SubSections/SubSection
      return
        <Labels>{$v/SubSectionName/text()}</Labels>,
      for $v in $set/SubSections/SubSection
        return
        <Values>{$v/Id/text()}</Values>
      )
    }
};

(: ======================================================================
   Returns a list of weight vectors tag name to look for inside Activity
   Sample output: 'Vectors-1', 'Vectors-7'
   ====================================================================== 
:)
declare function stats:encode-needs-weight( $filter as element(), $root as xs:string ) as xs:string* {
  let $prefix := substring($root, 1, string-length($root) - 1) 
  let $filter-top-tag := concat('Weight', $root)
  let $filter-var-tag := concat($prefix, 'Ref')
  return
    for $c in $filter/*[local-name(.) eq $filter-top-tag]/*[local-name(.) eq $filter-var-tag]
    return 
    concat($root, '-', $c)
};

(: ======================================================================
   Converts zero or one element into xs:double value, returns 0 if empty or non-number
   FIXME: share with workflow/final-report.xql (?)
   ======================================================================
:)
declare function stats:as-number( $n as element()? ) {
  let $res := number($n)
  return
    if (string($res) eq 'NaN') then
      0
    else
      $res
};

(: ======================================================================
   Converts zero or one element into xs:double valuscore, returns 0 if empty or non-number
   Reverses scale so that 1 is least positive evaluation and 5 is most positive
   ======================================================================
:)
declare function stats:as-score( $n as element()? ) {
  let $res := number($n)
  return
    if (string($res) eq 'NaN') then
      0
    else
      -$res + 6
};

(: ======================================================================
   Returns ordered sequence of 14 responses to evaluation questions as double
   ====================================================================== 
:)
declare function stats:gen-feedbacks-sample( $a as element() ) as xs:double* {
  let $fr := $a/FinalReport
  let $fra := $a/FinalReportApproval
  let $sme := $a/Evaluation
  return
    for $s in (
      stats:as-number($fra/Recognition/RatingScaleRef),
      stats:as-number($fra/Tools/RatingScaleRef),
      stats:as-number($sme//RatingScaleRef[@For eq 'SME1']),
      stats:as-number($sme//RatingScaleRef[@For eq 'SME2']),
      stats:as-number($fra/Profiles/RatingScaleRef),
      stats:as-number($sme//RatingScaleRef[@For eq 'SME3']),
      stats:as-number($fr/KAMPreparation/RatingScaleRef),
      stats:as-number($fr/ManagementTeam/RatingScaleRef),
      stats:as-number($sme//RatingScaleRef[@For eq 'SME7']),
      stats:as-number($fr/Dissemination/RatingScaleRef),
      stats:as-number($sme//RatingScaleRef[@For eq 'SME4']),
      stats:as-number($fr/ObjectivesAchievements/RatingScaleRef),
      stats:as-number($sme//RatingScaleRef[@For eq 'SME5']),
      stats:as-number($sme//RatingScaleRef[@For eq 'SME6'])
      )
    return 
      if ($s ne 0) then (-$s + 6) else 0 (: hard-coded reverse scale :)
};


(: ======================================================================
   Returns average of feedbacks at ranks if at least one is defined
   Returns non value 0 otherwise
   ====================================================================== 
:)
declare function local:calc-average(
  $feedbacks as xs:double*,
  $ranks as element()
  )
{
  let $vals := $feedbacks[position() = $ranks/Rank/text()][. ne 0]
  return (: computes if at least one answer :)
    if (empty($vals)) then
      0
    else
      avg($vals)
};

(: ======================================================================
   Returns the score for name variable filter using stats.xml definition
   ====================================================================== 
:)
declare function stats:calc-filter( 
  $name as xs:string, 
  $feedbacks as xs:double* 
  ) as xs:double
{
  let $meandef := fn:doc($globals:stats-uri)//Mean[@Filter eq $name]
  let $ranks := $meandef/Rank/text()
  return 
    if (empty($ranks)) then (: mean of means :)
      let $composition := $meandef/parent::Composition
      let $means := 
        for $m in $composition/Mean[@Filter ne $name]
        return local:calc-average($feedbacks, $m)
      return
        if (exists($means[. = 0])) then (: cannot compute :)
          0
        else
          avg($means)
    else (: computes if at least one answer :)
      local:calc-average($feedbacks, $meandef)
};

(: ======================================================================
   Returns true() if the sample with the input feedbacks satisfies 
   all the min max constraints in the filter-names, false() otherwise
   The feedbacks sequence MUST be ordered
   ====================================================================== 
:)
declare function stats:check-min-max( 
  $filter-names as xs:string*, 
  $min as xs:double*,
  $max as xs:double*,
  $feedbacks as xs:double* 
  ) as xs:boolean
{
  every $check in
    for $name at $i in $filter-names
    let $score := stats:calc-filter($name, $feedbacks)
    return ($score ne 0) and ($min[$i] <= $score) and ($score <= $max[$i])
  satisfies $check 
};

(: ======================================================================
   Implements stats access control policy for querying 
   ====================================================================== 
:)
declare function stats:filter-region-criteria( $user as xs:string,  $filter as element() ) as element()* {
  if (access:check-sight($user, 'region-manager')) then
    access:get-current-user-regions-as('region-manager')
  else
    $filter//RegionalEntityRef
};

(: ======================================================================
   Implements stats access control policy for querying 
   ====================================================================== 
:)
declare function stats:filter-kam-criteria( $user as xs:string,  $filter as element() ) as element()* {
  if (access:check-sight($user, 'kam')) then
      <AccountManagerRef>{ access:get-current-person-id($user) }</AccountManagerRef>
  else
    $filter//AccountManagerRef
};
