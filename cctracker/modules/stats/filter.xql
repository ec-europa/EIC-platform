xquery version "3.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Statistical filtering for diagrams view
   Return JSON data sample matching search mask criteria

   January 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace json="http://www.json.org";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace stats = "http://oppidoc.com/ns/cctracker/stats" at "stats.xqm";

declare option exist:serialize "method=json media-type=application/json";

declare variable $local:graph-weight-thresholds := '3';

(: ======================================================================
   Single CASE sample generation suitable for JSON conversion
   Tag names aligned with Variable and Vector elements content in stats.xml
   ======================================================================
:)
declare function local:gen-case-sample ( $p as element(), $c as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  let $e := $p/Information/Beneficiaries/*[PIC eq $c/PIC]
  let $na := $c/NeedsAnalysis
  return
    (
    <Prg>{ $p/Information/Call/FundingProgramRef/text() }</Prg>,
    <COf>{ $p/Information/Call/(SMEiCallRef|FTICallRef|FETCallRef)/text() }</COf>,
    <Ph>{ $p/Information/Call/(SMEiFundingRef | FETActionRef)/text() }</Ph>,
    for $i in $p/Information/Call//TopicRef
    return
      <Tp>{ $i/text() }</Tp>,
    <PO>{ $p/Information/ProjectOfficerRef/text() }</PO>,
    <CS>{ $c/StatusHistory/CurrentStatusRef/text() }</CS>,
    <Co>{ $e/Address/Country/text() }</Co>,
    <Nc>{ $e/DomainActivityRef/text() }</Nc>,
    for $i in $e//TargetedMarketRef
    return
      <TM>{ $i/text() }</TM>,
    <Sz>{ $e/SizeRef/text() }</Sz>,
    <Yr>{ $e/CreationYear/text() }</Yr>,
    <EEN>{ $c//RegionalEntityRef/text() }</EEN>,
    <KAM>{ $c//AccountManagerRef/text() }</KAM>,
    <SG>{ $na//SectorGroupRef/text() }</SG>,
    <IC>{ $na//InitialContextRef/text() }</IC>,
    <TC>{ $na//TargetedContextRef/text() }</TC>,
    for $i in $na//VectorRef
    return
      <Vct>{ $i/text() }</Vct>,
    for $i in $na//IdeaRef
    return
      <Ids>{ $i/text() }</Ids>,
    for $i in $na//ResourceRef
    return
      <Rsc>{ $i/text() }</Rsc>,
    for $i in $na//PartnerRef
    return
      <Ptn>{ $i/text() }</Ptn>
    )
};

(: ======================================================================
   Single ACTIVITY sample generation suitable for JSON conversion
   ======================================================================
:)
declare function local:gen-activity-sample ( $p as element(), $c as element(), $a as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  let $w := $a/Assignment/Weights
  return
    (
    <Prg>{ $p/Information/Call/FundingProgramRef/text() }</Prg>,
    <Coach>{ $a//ResponsibleCoachRef/text() }</Coach>,
    <Sv>{ $a/Assignment/ServiceRef/text() }</Sv>,
    <AS>{ $a/StatusHistory/CurrentStatusRef/text() }</AS>,
    for $i in $w/*[starts-with(local-name(.), 'V') and (. = $local:graph-weight-thresholds)] (: Vectors-* :)
    let $val := substring-after(local-name($i), '-')
    return
      <AVct>{ $val }</AVct>,
    for $i in $w/*[starts-with(local-name(.), 'I') and (. = $local:graph-weight-thresholds)] (: Ideas-* :)
    let $val := substring-after(local-name($i), '-')
    return
      <AIds>{ $val }</AIds>,
    for $i in $w/*[starts-with(local-name(.), 'R') and (. = $local:graph-weight-thresholds)] (: Resources-* :)
    let $val := substring-after(local-name($i), '-')
    return
      <ARsc>{ $val }</ARsc>,
    for $i in $w/*[starts-with(local-name(.), 'P') and (. = $local:graph-weight-thresholds)] (: Partners-* :)
    let $val := substring-after(local-name($i), '-')
    return
      <APtn>{ $val }</APtn>,
    <CA>{ $a/FinalReport//CommunicationAdviceRef/text() }</CA>,
    <KA>{ $a/FinalReportApproval//CommunicationAdviceRef/text() }</KA>
    )
};

(: ======================================================================
   KPI data for single ACTIVITY generation suitable for JSON conversion

   Correspondance (dictionary.xml extract) :

          q1 : To KAM: The top management understands the value of the coaching
          q2 : To KAM: I felt confident using the needs analysis tool
   SME1 : q3 : To SME: [name of KAM] helped us to identify relevant business needs
   SME2 : q4 : To SME: The needs analysis performed together with [name of KAM] lead our company to take internal actions
          q5 : To KAM: I could find suitably profiled coaches in the coach database
   SME3 : q6 : To SME: I was well informed about coaches to be able to choose the appropriate one
          q7 : To Coach: The KAM prepared constructively my interaction with the SME beneficiary
          q8 : To Coach: The management team of the company was actively engaged in the coaching process
   SME7 : q9 : To SME: I would recommend business innovation coaching to other companies
          q10 : To Coach: I do consider the coaching experience suitable to be communicated as a success story
   SME4 : q11 : To SME: Thanks to the coaching, our approach to company challenges was/has changed
          q12 : To coach: The planned tasks and objectives were achieved
   SME5 : q13 : To SME: Thanks to the coaching, we are expecting our business innovation project to progress faster
   SME6 : q14 : To SME: Thanks to the coaching, our business strategy was improved
   ====================================================================== 
:)
declare function local:gen-kpi-sample( $p as element(), $c as element(), $a as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  local:gen-activity-sample($p, $c, $a, $flags, $lang),
  let $fr := $a/FinalReport
  let $fra := $a/FinalReportApproval
  let $sme := $a/Evaluation
  return 
    for $value in (
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
      stats:as-number($sme//RatingScaleRef[@For eq 'SME6']),
      stats:as-number(($fra/Dialogue/RatingScaleRef)[last()])
      )
    return
      <Q json:literal="true">{ $value }</Q>
};

let $cmd := oppidum:get-command()
let $submitted := oppidum:get-data()
(: decodes stats specification name from submitted root element name :)
let $target := lower-case(substring-before(local-name($submitted), 'Filter'))
let $filter-spec-uri := oppidum:path-to-config('stats.xml')
(: gets stats specification :)
let $stats-spec := fn:doc($filter-spec-uri)/Statistics//Filter[@Page = $target]
let $sets := distinct-values($stats-spec//Set)
let $cases := if ('Cases' = $sets) then
                stats:gen-cases($submitted, (), 'en', function-lookup(xs:QName("local:gen-case-sample"), 4)) 
              else 
                ()
let $activities := if ('Activities' = $sets) then
                     let $gen := if ($target eq 'kpi') then 'local:gen-kpi-sample' else 'local:gen-activity-sample'
                     return
                       stats:gen-activities($submitted, $target, 'en', function-lookup(xs:QName($gen), 5)) 
                  else
                    ()
let $action := string($cmd/@action)
return
  if ((access:check-stats-action($target, $action, false()))) then 
    <DataSet Size="{count($activities)}">
      { $cases }
      { $activities }
      <Variables>
        {
        for $d in $stats-spec//Composition
        return stats:gen-composition-domain($d),
        for $d in $stats-spec//*[local-name(.) ne 'Composition'][@Selector]
        return stats:gen-selector-domain($d, $d/@Selector, $d/@Format),
        for $d in $stats-spec//*[@WorkflowStatus]
        return stats:gen-workflow-status-domain($d, $d/@WorkflowStatus),
        for $d in distinct-values($stats-spec//@Domain)
        return
          if ($d eq 'nuts') then
            stats:gen-nuts-domain(($cases, $activities))
          else if ($d eq 'year') then
            stats:gen-year-domain(($cases, $activities))
          else if ($d eq 'regions') then
            stats:gen-regions-domain(($cases, $activities))
          else if ($d eq 'CaseImpact') then
            for $i in $stats-spec/Charts/Chart/Vector[@Domain eq 'CaseImpact']
            return
              stats:gen-case-vector($i/text(), string($i/@Section))
          else if ($d eq 'cut-off') then
            stats:gen-cut-off-domain(($cases, $activities))
          else if ($d eq 'funding-phase') then
            stats:gen-funding-phase-domain(($cases, $activities))
          else
            (),
        for $d in $stats-spec//*[@Persons]
        let $tag := string($d)
        let $refs := $cases/*[local-name(.) eq $tag] | $activities/*[local-name(.) eq $tag]
        return stats:gen-persons-domain-for($refs, $tag)
        }
      </Variables>
    </DataSet>
  else
    oppidum:throw-error('FORBIDDEN', ())
