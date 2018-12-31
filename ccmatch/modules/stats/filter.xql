xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Statistical filtering for diagrams view

   TODO:
   - factorize gen-cases and gen-activities with filter.xql in stats.xqm

   January 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace json="http://www.json.org";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace stats = "http://oppidoc.com/ns/cctracker/stats" at "stats.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "../suggest/match.xqm";

declare option exist:serialize "method=json media-type=application/json";

declare variable $local:weight-thresholds := ('2', '3');
declare variable $local:graph-weight-thresholds := '3';

(: ======================================================================
   CASE samples set generation matching $filter criteria
   See also FLWOR in search-by-criteria.xql
   ======================================================================
:)
declare function local:gen-coaches ( $filter as element(), $lang as xs:string ) as element()* {
  (:let $user := oppidum:get-current-user():)

  (:let $host := stats:filter-region-criteria($user, $filter):)
  let $host := '1'
  let $ranks := fn:doc($globals:feeds-uri)/Feeds/Feed[@For eq $host]//Mean[@Filter eq 'SME']/Rank

  (: FIXME: hard coded 1 to 4 :)
  let $status := $filter//AccreditationStatusRef
  let $start-date := $filter/AccreditationStartDate/text()
  let $end-date := $filter/AccreditationEndDate/text()
  let $status-any-time := if ($start-date or $end-date) then () else $status
  let $status-after := if ($start-date and not($end-date)) then if (empty($status)) then 1 to 4 else $status else ()
  let $status-before := if ($end-date and not($start-date)) then if (empty($status)) then 1 to 4 else $status else ()
  let $status-between := if ($start-date and $end-date) then if (empty($status)) then 1 to 4 else $status else ()
  let $availability := $filter//YesNoAvailRef
  let $visibility := $filter//YesNoAcceptRef
  let $service := $filter//ServiceRef
  let $service-level := stats:get-expertise-for($filter, 'Services')

  let $coach := $filter//CoachRef
  let $sex := $filter//GenderRef
  let $country := $filter//Country
  let $languages := $filter//EU-LanguageRef
  let $perf := $filter/Performance[(Min ne '') or (Max ne '')]
  let $perf-min := if ($perf/Min) then number($perf/Min) else 1
  let $perf-max := if ($perf/Max) then number($perf/Max) else 5
  let $service-years := $filter//ServiceYearRef

  let $domain := $filter//DomainActivityRef
  let $domain-level := stats:get-expertise-for($filter, 'DomainsOfActivities')
  let $market := $filter//TargetedMarketRef/text()
  let $market-level := stats:get-expertise-for($filter, 'TargetedMarkets')
  let $life-cycle := $filter//InitialContextRef
  let $life-cycle-level := stats:get-expertise-for($filter, 'InitialContexts')

  let $vector := $filter//VectorRef/text()
  let $vector-level := stats:get-expertise-for($filter, 'Vectors')
  let $idea := $filter//IdeaRef/text()
  let $idea-level := stats:get-expertise-for($filter, 'Ideas')
  let $resource := $filter//ResourceRef/text()
  let $resource-level := stats:get-expertise-for($filter, 'Resources')
  let $partner := $filter//PartnerRef/text()
  let $partner-level := stats:get-expertise-for($filter, 'Partners')
  
  return
    for $c in fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = '4']
    where     (empty($status-before) or $c/Hosts/Host[@For eq $host]/AccreditationRef[. = $status-before]/@Date <= $end-date)
          and (empty($status-after) or $c/Hosts/Host[@For eq $host]/AccreditationRef[. = $status-after]/@Date >= $start-date)
          and (empty($status-between) or $c/Hosts/Host[@For eq $host]/AccreditationRef[. = $status-between][@Date >= $start-date and @Date <= $end-date])
          and (empty($status-any-time) or $c/Hosts/Host[@For eq $host]/AccreditationRef = $status-any-time)
          and (empty($availability) or $c/Preferences/Coaching[@For eq $host]/YesNoAvailRef = $availability)
          and (empty($visibility) or $c/Preferences/Visibility[@For eq $host]/YesNoAcceptRef = $visibility)
          and (empty($service) or $c/Skills[@For eq 'Services']/Skill[@For = $service] = $service-level)
          and (empty($coach) or $c/Id = $coach)
          and (empty($sex) or $c/Information/Sex = $sex)
          and (empty($country) or $c/Information/Address/Country = $country)
          and (empty($languages) or $c/Knowledge/SpokenLanguages/EU-LanguageRef = $languages)
          and (empty($perf) or stats:check-min-max($c, $host, $perf-min, $perf-max))
          and (empty($service-years) or $c/Knowledge/IndustrialManagement/ServiceYearRef = $service-years)
          and (empty($domain) or exists($c/Skills[@For eq 'DomainActivities']//Skill[@For = $domain and . = $domain-level]))
          and (empty($market) or exists($c/Skills[@For eq 'TargetedMarkets']//Skill[@For = $market and . = $market-level]))
          and (empty($life-cycle) or exists($c/Skills[@For eq 'LifeCycleContexts']//Skill[@For = $life-cycle and . = $life-cycle-level]))
          and (empty($vector) or exists($c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '1']/Skill[@For = $vector and . = $vector-level]))
          and (empty($idea) or exists($c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '2']/Skill[@For = $idea and . = $idea-level]))
          and (empty($resource) or exists($c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '3']/Skill[@For = $resource and . = $resource-level]))
          and (empty($partner) or exists($c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '4']/Skill[@For = $partner and . = $partner-level]))
    return
      <Coaches Visibility="{$c/Preferences/Visibility[@For eq $host]/YesNoAcceptRef}">
        {
        local:gen-coach-sample($c, $service-level, $domain-level, $market-level, $life-cycle-level, $vector-level, $idea-level, $resource-level, $partner-level, $ranks)
        }
      </Coaches>
};

(: ======================================================================
   Single CASE sample generation suitable for JSON conversion
   Tag names aligned with Variable and Vector elements content in stats.xml
   FIXME: parameterize Host
   ======================================================================
:)
declare function local:gen-coach-sample ( 
  $c as element(), 
  $service-level as xs:string*,
  $domain-level as xs:string*,
  $market-level as xs:string*,
  $life-cycle-level as xs:string*,
  $vector-level as xs:string*,
  $idea-level as xs:string*,
  $resource-level as xs:string*,
  $partner-level as xs:string*,
  $ranks as xs:integer*
  ) as element()* 
{
  let $host := '1' (: TODO: multi-hosts :)
  let $info := $c/Information
  return
    (
    <Name>{ display:gen-person-name($c, 'en') }</Name>,
    (: Variables :)
    <AS>{ $c/Hosts/Host[@For eq '1']/AccreditationRef/text() }</AS>,
    <WR>{ $c/Hosts/Host[@For eq '1']/WorkingRankRef/text() }</WR>,
    if (exists($c/Preferences/Visibility[@For eq $host]/YesNoAcceptRef)) then
      <VC>{ $c/Preferences/Visibility[@For eq $host]/YesNoAcceptRef/text() }</VC>
    else
      (), (: implicitly not visible :)
    if (exists($c/Preferences/Coaching[@For eq $host]/YesNoAvailRef)) then
      <AC>{ $c/Preferences/Coaching[@For eq $host]/YesNoAvailRef/text() }</AC>
    else
      <AC>1</AC>, (: implicitly available :)
    <Co>{ $info//Country/text() }</Co>,
    <Sx>{ $info/Sex/text() }</Sx>,
    (: Sv: services vector :)
    for $item in $c/Skills[@For eq 'Services']/Skill[ . = $service-level]
    return <Sv>{ string($item/@For) }</Sv>,
    (: Lg: EU languages vector :)
    for $item in $c/Knowledge/SpokenLanguages/EU-LanguageRef
    return <Lg>{ string($item) }</Lg>,
    (: Pfs: SME performances vector :)
    for $scores in $c//Feed[@For eq $host]/Evaluation/Scores
    return
      for $item in tokenize($scores, ' ')[position() = $ranks]
      where $item ne '0'
      return (: converts score back to RatingScales where 1 is better than 5 :)
        <Pfs>{ -number($item) + 6  }</Pfs>,
    (: Nc: nace codes vector :)
    for $item in $c/Skills[@For eq 'DomainActivities']//Skill[. = $domain-level]
    return <Nc>{ string($item/@For) }</Nc>,
    (: TM: targeted markets vector :)
    for $item in $c/Skills[@For eq 'TargetedMarkets']//Skill[. = $market-level]
    return <TM>{ string($item/@For) }</TM>,
    (: LC: life cycle contexts vector :)
    for $item in $c/Skills[@For eq 'LifeCycleContexts']//Skill[. = $life-cycle-level]
    return <LC>{ string($item/@For) }</LC>,
    (: Vct: needs vector :)
    for $item in $c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '1']/Skill[. = $vector-level]
    return <Vct>{ string($item/@For) }</Vct>,
    (: Ids: idea sources vector :)
    for $item in $c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '2']/Skill[. = $idea-level]
    return <Ids>{ string($item/@For) }</Ids>,
    (: Rsc: resources vector :)
    for $item in $c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '3']/Skill[. = $resource-level]
    return <Rsc>{ string($item/@For) }</Rsc>,
    (: Ptn: partnerships vector :)
    for $item in $c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '4']/Skill[. = $partner-level]
    return <Ptn>{ string($item/@For) }</Ptn>
    )
};

let $cmd := oppidum:get-command()
let $submitted := oppidum:get-data()
(: decodes stats specification name from submitted root element name :)
let $target := lower-case(substring-before(local-name($submitted), 'Filter'))
let $kpi := $target eq 'kpi'
let $filter-spec-uri := oppidum:path-to-config('stats.xml')
(: gets stats specification :)
let $stats-spec := fn:doc($filter-spec-uri)/Statistics//Filter[@Page = $target]
let $sets := distinct-values($stats-spec//Set)
let $coaches := if ('Coaches' = $sets) then local:gen-coaches($submitted, 'fr') else  ()
let $action := string($cmd/@action)
return
  (: FIXME: if ((access:check-stats-action($target, $action, false()))) then:)
  if (true()) then 
    <DataSet Size="{count($coaches)}">
      { $coaches }
      <Variables>
        {
        for $d in $stats-spec//Composition
        return stats:gen-composition-domain($d),
        for $d in $stats-spec//*[local-name(.) ne 'Composition'][@Selector and (@Selector ne 'Sex')]
        return stats:gen-selector-domain($d, $d/@Selector, $d/@Format),
        <Sx>
          <Labels>Male</Labels>
          <Labels>Female</Labels>
          <Values>M</Values>
          <Values>F</Values>
        </Sx>,
        for $d in $stats-spec//*[@WorkflowStatus]
        return stats:gen-workflow-status-domain($d, $d/@WorkflowStatus),
        for $d in distinct-values($stats-spec//@Domain)
        return
          if ($d eq 'nuts') then
            stats:gen-nuts-domain($coaches)
          else if ($d eq 'year') then
            stats:gen-year-domain($coaches)
          else if ($d eq 'regions') then
            stats:gen-regions-domain($coaches)
          else if ($d eq 'CaseImpact') then
            for $i in $stats-spec/Charts/Chart/Vector[@Domain eq 'CaseImpact']
            return
              stats:gen-case-vector($i/text(), string($i/@Section))
          else
            (),
        for $d in $stats-spec//*[@Persons]
        let $tag := string($d)
        let $refs := $coaches/*[local-name(.) eq $tag]
        return stats:gen-persons-domain-for($refs, $tag)
        }
      </Variables>
      { $stats-spec/Charts }
    </DataSet>
  else
    oppidum:throw-error('FORBIDDEN', ())
