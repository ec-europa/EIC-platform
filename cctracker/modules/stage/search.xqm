xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Authors: Stéphane Sire <s.sire@opppidoc.fr>

   Stage request handling

   November 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace search = "http://platinn.ch/coaching/search";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

(: ======================================================================
   Returns the saved search request in the user's profile if it exists
   or a default one otherwise
   ======================================================================
:)
declare function search:get-default-request () as element() {
  let $profile := access:get-current-person-profile()
  return
    if ($profile/SearchStageRequest) then
      $profile/SearchStageRequest
    else
      <Request/>
};

declare function local:gen-project-sample ( $p as element(), $lang as xs:string ) as element()* {
  (
  $p/Id,
  $p/Information/(Acronym | Title),
  <Program>{ string(misc:unreference($p/Information/Call/FundingProgramRef)/@_Display) }</Program>,
  <CallRef>{ string(misc:unreference($p/Information/Call/(SMEiCallRef | FTICallRef | FETCallRef ))/@_Display) }</CallRef>,
  <FundingRef>{ string(misc:unreference($p/Information/Call/(SMEiFundingRef | FETActionRef))/@_Display) }</FundingRef>,
  <Grant>{ display:gen-display-date($p/Information/Contract/Date, $lang) }</Grant>,
  if (empty($p/Cases/Case)) then
    <Status>Nothing initiated yet</Status>
  else
    ()
  )
};

(: ======================================================================
   Generates Case information fields to display in result table for a given case
   FIXME: hard-coded status name
   ======================================================================
:)
declare function local:gen-case-sample ( $c as element(), $lang as xs:string ) as element()* {
  let $p := $c/../..
  let $e := $p/Information/Beneficiaries/(Coordinator | Partner)[PIC eq $c/PIC]
  let $manager := $c/Management/AccountManagerRef
  return
    (
    <Enterprise>{ $e/Id, $e/Name }</Enterprise>,
    $e/Address/Country,
    $c/No,
    <Coach>
      {
      if ($manager[. ne '']) then (
        <Id>{$manager/text()}</Id>,
        <FullName>{ display:gen-person-name($manager/text(), $lang) }</FullName>
        )
      else if ($c/StatusHistory/CurrentStatusRef = ('1', '9', '10')) then
        <No/>
      else if ($c/StatusHistory/CurrentStatusRef eq '2') then   
        <Soon/>
      else 
        <Miss/>
      }
    </Coach>,
    if (empty($c/Activities/Activity)) then
      <Status>{ display:gen-workflow-status-name('Case', $c/StatusHistory/CurrentStatusRef, $lang) }</Status>
    else
      ()
    )
};

(: ======================================================================
   Generates Activity information fields to display in result table for a given activity
   FIXME: hard-coded status name
   ======================================================================
:)
declare function local:gen-activity-sample ( $a as element(), $lang as xs:string ) as element() {
  let $coach-id := $a/Assignment/ResponsibleCoachRef/text()
  return
    <Activity>
      { $a/@legacy }
      { $a/No }
      <Title>{ display:gen-activity-title( $a/ancestor::Case, $a, $lang) }</Title>
      <Coach>
        {
        if ($coach-id) then (
          <Id>{ $coach-id }</Id>,
          <FullName>{ display:gen-person-name($coach-id, $lang) }</FullName>
          )
        else if ($a/StatusHistory/CurrentStatusRef eq '1') then
          <Soon/>
        else
          <Miss/>
        }
      </Coach>
      <Status>{ display:gen-workflow-status-name('Activity', $a/StatusHistory/CurrentStatusRef, $lang) }</Status>
    </Activity>
};

declare function search:find-all-cases-activities ( $lang as xs:string ) as element() {
  (: --- access control layer --- :)
  let $profile := access:get-current-person-profile()
  let $person := $profile/ancestor::Person
  let $omni-sight := access:check-omniscient-user($profile)
  return
    <Projects>
      { local:open-access($omni-sight, (), (), ()) }
      { 
      for $p in fn:collection($globals:projects-uri)//Project
      let $omni-p := $omni-sight or access:check-omniscient-project-user($person, $p)
      let $can-p := $omni-p or access:check-user-can-open-project($person, $p)
      return
        <Project>
          { local:open-access($omni-sight, $can-p, (), ()) }
          { local:gen-project-sample($p, $lang) }
          <Cases>
          {
          for $c in $p/Cases/Case
          let $omni-case := $omni-sight or access:check-omniscient-case-user($person, $c)
          let $can-case := $omni-case or access:check-user-can-open-case($person, $c)
          return
            <Case>
              { local:open-access($omni-sight, $can-p, $can-case, ()) }
              { local:gen-case-sample($c, $lang) }
              <Activities>
                {
                for $a in $c/Activities/Activity
                order by $a/CreationDate
                return local:gen-activity-sample($a, $lang)
                }
              </Activities>
            </Case>
          }
          </Cases>
        </Project>
      }
    </Projects>
};

declare function local:open-access( $all as xs:boolean, $project as xs:boolean?, $case as xs:boolean?, $activity as xs:boolean? ) as attribute()?
{
  if ($all and empty($project) and empty($case) and empty($activity)) then (: top-level call :)
    attribute { 'Open' } { 'y' }
  else if (not($all) and $project and empty($case) and empty($activity)) then (: project level call :)
    attribute { 'Open' } { 'y' }
  else if (not($all) and $case and empty($activity)) then (: case level call :)
    attribute { 'Open' } { 'y' }
  else if (not($all) and $activity) then (: activity level call :)
    attribute { 'Open' } { 'y' }
  else
    ()
};

(: ======================================================================
   Removes the satellite part of a list of Enterprise name elements
   and returns a list of strings
   ======================================================================
:)
declare function local:filter-enterprise-names( $names as element()* ) as xs:string* {
  for $n in $names
  return
    if (contains($n, '::')) then
      substring-before($n, '::')
    else
      $n
};

(: ======================================================================
   FIXME: remove [. ne 'any'] guard because optional filter does not works
   after data has been loaded into the editor (to be fixed in AXEL) with load function
   such as with saved filters
   ======================================================================
:)
declare function search:find-cases-activities ( $filter as element(), $lang as xs:string ) as element() {

  (: --- access control layer --- :)
  let $profile := access:get-current-person-profile()
  let $person := $profile/ancestor::Person
  let $omni-sight := access:check-omniscient-user($profile)

  (: project filter :)
  let $pid := $filter/ProjectId/text()
  
  let $phase :=  $filter//FundingRef/text()(: $filter//PhaseRef/text() replace by the type of action :)
  let $cutoff := $filter//SMEiCallRef/text()(: $filter//CutOffDateRef/text() :)
  let $acronym := $filter//Acronym/text()
  
  (: guess induced program if not selected explicitly :)
  let $prog := $filter//FundingProgramRef/text()
  let $callsel := collection($globals:global-info-uri)//Selector[./Group/Selector/Option[Code = $cutoff]]/@Name
  let $prog := if ($prog) then $prog else collection($globals:global-info-uri)//Selector[@Name eq 'FundingPrograms']/Option[Calls eq $callsel]/Id/text()
  let $prog := if ($prog) then $prog else for $p in $phase return substring-before($p, '-')

  let $topic := $filter/Topics/TopicRef/text()
  let $eicpanel := $filter/EICPanels/EICPanelRef/text()
  let $eicmainpanel := exists($filter/EICMainPanel)
  let $topeicpanel := collection('/db/sites/cctracker/global-information')//Selector[@Name eq 'EICPanels']//Option[Code = $eicpanel]/../../Code/text()
  let $fettopic := $filter/FETTopics/FETTopicRef/text()
  let $fetmainpanel := exists($filter/FETMainPanel)
  
  (: --- client enterprise filter --- :)
  let $enterprise := local:filter-enterprise-names($filter//Name)
  let $country := $filter//Country/text()
  let $year := $filter//CreationYear/text()
  let $size := $filter//SizeRef/text()
  let $domain := $filter//DomainActivityRef/text()
  let $market := $filter//TargetedMarketRef/text()
  let $filter-enterprise := not(empty(($enterprise, $country, $year, $size, $domain, $market)))

  (: --- case filter --- :)
  let $case := $filter/CaseNumber/text()
  let $case-manager := $filter/CaseCoaches/CoachRef/text()
  let $initial-ctx := $filter//InitialContextRef/text()
  let $targeted-ctx := $filter//TargetedContextRef/text()
  let $vector := $filter//VectorRef/text()
  let $idea := $filter//IdeaRef/text()
  let $resource := $filter//ResourceRef/text()
  let $partner := $filter//PartnerRef/text()
  
  (: new criteria... :)
  let $po := $filter//ProjectOfficerRef/text()
  let $explicit-entity := $filter/RegionalEntities/RegionalEntityRef/text()
  let $case-entity := 
    let $nuts := $filter//Nuts/text()
    return
      if (empty($nuts)) then
        $explicit-entity
      else
        let $nuts-to-entity := distinct-values(fn:collection($globals:regions-uri)//Region[NutsCodes/Nuts[. = $nuts]]/Id/text())
        return 
          if (empty($explicit-entity)) then
            $nuts-to-entity
          else if ($nuts-to-entity = $explicit-entity) then
            $nuts-to-entity[. = $explicit-entity]
          else (: trick to return no result :)
            '-1'
  let $case-start-date := $filter/CasePeriod/StartDate[. ne 'any']/text()
  let $case-end-date := $filter/CasePeriod/EndDate[. ne 'any']/text()
  let $case-status := $filter//CaseActivityStatusRef/text()
  let $case-status-any-time := if ($case-start-date or $case-end-date) then () else $case-status
  let $case-status-after := if ($case-status and $case-start-date and not($case-end-date)) then $case-status else ()
  let $case-status-before := if ($case-status and $case-end-date and not($case-start-date)) then $case-status else ()
  let $case-status-between := if ($case-status and $case-start-date and $case-end-date) then $case-status else ()
  let $sector := $filter//SectorGroupRef/text()
  let $filter-case := not(empty(($case, $case-status-any-time, $case-status-before, $case-status-after, $case-status-between, $sector, $explicit-entity, $case-entity, $case-manager, $initial-ctx, $targeted-ctx, $vector, $idea, $resource, $partner, $sector)))

  (: --- activity filter --- :)
  let $activity := $filter/ActivityNumber/text()
  let $start-date := $filter/Period/StartDate[. ne 'any']/text()
  let $end-date := $filter/Period/EndDate[. ne 'any']/text()
  let $status := $filter//ActivityStatusRef/text()
  let $status-any-time := if ($start-date or $end-date) then () else $status
  let $status-after := if ($status and $start-date and not($end-date)) then $status else ()
  let $status-before := if ($status and $end-date and not($start-date)) then $status else ()
  let $status-between := if ($status and $start-date and $end-date) then $status else ()
  let $service := $filter//ServiceRef/text()
  let $activity-coach := $filter/ActivityCoaches/CoachRef/text()
  let $communication := $filter/ToAppearsInNews[. ne '']/text()
  let $filter-activity := not(empty(($activity, $status-any-time, $status-before, $status-after, $status-between, $service, $activity-coach, $communication)))

  return
    if ($case-entity = '-1') then (: short cut for mutually exclusive condition :)
      <Projects Cause="Exclusive"/>
    else
      <Projects>
      { local:open-access($omni-sight, (), (), ()) }
      {
      for $p in fn:collection($globals:projects-uri)//Project
        [empty($pid) or .[Id eq $pid]]
        [empty($prog) or ./Information/Call[FundingProgramRef = $prog]]
        [empty($po) or ./Information[ProjectOfficerRef = $po]]
        [empty($enterprise) or ./Information/Beneficiaries/(Coordinator | Partner)/Name = $enterprise]
        [empty($acronym) or ./Information[Acronym = $acronym]]
        [empty($topic) or ./Information/Call/CallTopics/TopicRef = $topic]
        [empty($eicpanel) or ./Information/Call/EICPanels/EICPanelRef[. = $eicpanel][not($eicmainpanel) or @Order eq '1'] or ./Information/Call/EICPanels/EICPanelRef[. = $topeicpanel][not($eicmainpanel) or @Order eq '1']]
        [empty($fettopic) or ./Information/Call/FETTopics/FETTopicRef[. = $fettopic][not($fetmainpanel) or @Order eq '1']]
      where
      (empty($cutoff)
      or ($prog = '1' and (some $ref in $cutoff satisfies $p/Information/Call[SMEiCallRef eq $ref]))
      or ($prog = '2' and (some $ref in $cutoff satisfies $p/Information/Call[FTICallRef eq $ref]))
      or ($prog = '3' and (some $ref in $cutoff satisfies $p/Information/Call[FETCallRef eq $ref]))
      )
      and (empty($phase)
      or ($prog = '1' and (some $ref in $phase satisfies $p/Information/Call[SMEiFundingRef eq $ref]))
      or $prog = '2'
      or ($prog = '3' and (some $ref in $phase satisfies $p/Information/Call[FETActionRef eq $ref]))
      )
      (: --- client enterprise filter --- :)
      and (
            not($filter-enterprise) or
              (
              let $e := $p/Information/Beneficiaries(:/(Coordinator | Partner):)
              return
                (
                    (empty($country) or $e//Country = $country)
                and (empty($year) or $e//CreationYear eq $year)
                and (empty($size) or $e//SizeRef = $size)
                and (empty($domain) or $e//DomainActivityRef = $domain)
                and (empty($market) or $e//TargetedMarketRef = $market)
                )
              )
          )
      return
        let $omni-p := $omni-sight or access:check-omniscient-project-user( $person, $p )
        let $can-p := $omni-p or access:check-user-can-open-project( $person, $p )
        return
          if ($filter-case or $filter-activity) then
            let $cases := 
              for $c in $p/Cases/Case
                [empty($case) or .[No eq $case]]
                [empty($case-manager) or ./Management[AccountManagerRef = $case-manager]]
                [empty($case-entity) or ./ManagingEntity[RegionalEntityRef = $case-entity]]
                [empty($case-status-any-time) or .[StatusHistory[CurrentStatusRef = $case-status-any-time]]]
                [empty($initial-ctx) or ./NeedsAnalysis/Context[InitialContextRef = $initial-ctx]][empty($targeted-ctx) or ./NeedsAnalysis/Context[TargetedContextRef = $targeted-ctx]]
                [empty($vector) or ./NeedsAnalysis/Impact/Vectors[VectorRef = $vector]]
                [empty($idea) or ./NeedsAnalysis/Impact/Ideas[IdeaRef = $idea]]
                [empty($resource) or ./NeedsAnalysis/Impact/Resources[ResourceRef = $resource]]
                [empty($partner) or ./NeedsAnalysis/Impact/Partners[PartnerRef = $partner]]
                [empty($sector) or ./NeedsAnalysis/Stats[SectorGroupRef = $sector]]
              where
                (empty($case-status-after) or
                     ($c/StatusHistory/CurrentStatusRef = $case-status-after
                      and $c/StatusHistory/Status[./ValueRef eq $c/StatusHistory/CurrentStatusRef/text()][./Date >= $case-start-date]))
                and (empty($case-status-before) or
                     ($c/StatusHistory/CurrentStatusRef = $case-status-before
                      and $c/StatusHistory/Status[./ValueRef eq $c/StatusHistory/CurrentStatusRef/text()][./Date <= $case-end-date]))
                and (empty($case-status-between) or
                     ($c/StatusHistory/CurrentStatusRef = $case-status-between
                      and $c/StatusHistory/Status[./ValueRef eq $c/StatusHistory/CurrentStatusRef/text()][./Date >= $case-start-date and ./Date <= $case-end-date]))
              return $c
            return
              if (count($cases) > 0) then
                for $c in $cases
                let $omni-case := $omni-sight or access:check-omniscient-case-user( $person, $c )
                let $can-case := $omni-p or access:check-user-can-open-case( $person, $c )
                return
                  if ($filter-activity) then
                    let $activities :=
                      for $a in $c/Activities/Activity
                      where (empty($activity) or $a/No = $activity)
                            and (empty($activity-coach) or $a/Assignment/ResponsibleCoachRef = $activity-coach)
                            and (empty($status-after) or
                                 ($a/StatusHistory/CurrentStatusRef = $status-after
                                  and $a/StatusHistory/Status[./ValueRef eq $a/StatusHistory/CurrentStatusRef/text()][./Date >= $start-date]))
                            and (empty($status-before) or
                                 ($a/StatusHistory/CurrentStatusRef = $status-before
                                  and $a/StatusHistory/Status[./ValueRef eq $a/StatusHistory/CurrentStatusRef/text()][./Date <= $end-date]))
                            and (empty($status-between) or
                                 ($a/StatusHistory/CurrentStatusRef = $status-between
                                  and $a/StatusHistory/Status[./ValueRef eq $a/StatusHistory/CurrentStatusRef/text()][./Date >= $start-date and ./Date <= $end-date]))
                            and (empty($status-any-time) or $a[StatusHistory[CurrentStatusRef = $status-any-time]])
                            and (empty($service) or $a/Assignment/ServiceRef = $service)
                            and (empty($communication) or $a//CommunicationAdviceRef[. = $communication])
                      order by $a/CreationDate
                      return $a
                    return
                      if (count($activities) > 0) then
                        <Project>
                          { local:open-access($omni-sight, $can-p, (), ()) }
                          { local:gen-project-sample($p, $lang) }
                          <Cases>
                            <Case>
                              { local:open-access($omni-sight, $can-p, $can-case, ()) }
                              { local:gen-case-sample($c, $lang) }
                              <Activities>
                                {
                                for $a in $activities
                                order by $a/CreationDate
                                return local:gen-activity-sample($a, $lang)
                                }
                              </Activities>
                            </Case>
                          </Cases>
                        </Project>
                      else
                        ()
                  else
                    <Project>
                      { local:open-access($omni-sight, $can-p, (), ()) }
                      { local:gen-project-sample($p, $lang) }
                      <Cases>
                        <Case>
                          { local:open-access($omni-sight, $can-p, $can-case, ()) }
                          { local:gen-case-sample($c, $lang) }
                          <Activities>
                            {
                            for $a in $c/Activities/Activity
                            order by $a/CreationDate
                            return local:gen-activity-sample($a, $lang)
                            }
                          </Activities>
                        </Case>
                      </Cases>
                    </Project>
              else
                ()
          else (: search only for the project and not a specific case/activity in it :)
            <Project>
              { local:open-access($omni-sight, $can-p, (), ()) }
              { local:gen-project-sample($p, $lang) }
              <Cases>
                {
                for $c in $p/Cases/Case
                let $omni-case := $omni-sight or access:check-omniscient-case-user( $person, $c )
                let $can-case := $omni-p or access:check-user-can-open-case( $person, $c )
                order by $c/CreationDate
                return
                  <Case>
                    { local:open-access($omni-sight, $can-p, $can-case, ()) }
                    { local:gen-case-sample($c, $lang) }
                    <Activities>
                       {
                       for $a in $c/Activities/Activity
                       order by $a/CreationDate
                       return local:gen-activity-sample($a, $lang)
                       }
                    </Activities>
                  </Case>
                }
              </Cases>
            </Project>
      }
      </Projects>
};

(: ======================================================================
   Returns Cases and Activities matching request
   also returns individual Coach modal windows
   TODO: return Enterprise modal windows
   ======================================================================
:)
declare function search:fetch-cases-and-activities ( $request as element() , $lang as xs:string ) as element()* {

 if ((count($request/*/*) + count($request/*[local-name(.)][normalize-space(.) != ''])) = 0) then (: empty request :)
    if (request:get-parameter('_confirmed', '0') = '0') then
      (
      <Confirm/>,
      response:set-status-code(202)
      )
    else
      <Results>{ search:find-all-cases-activities($lang) }</Results>
  else
    <Results>{ search:find-cases-activities($request, $lang)}</Results>
};
