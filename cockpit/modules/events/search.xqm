xquery version "3.0";
(: ------------------------------------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors: Stéphane Sire <s.sire@opppidoc.fr>

   Enterprise search

   April 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace search = "http://oppidoc.com/ns/application/search";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";

(: ======================================================================
   Generates Enterprise information fields to display in result table
   The Acronym column contains the project acronym with the project ID 
   (grant agreement number) between parenthesis
   FIXME: decode Status using real event worklow id (not always OTF)
   ======================================================================
:)
declare function local:gen-enterprise-sample ( $ev as element(), $events as element()* ) as element() {
  let $e := $ev/../..
  let $info := $ev/../../Information
  let $event-def := $events[Id = $ev/Id]
  return
    <Users>
      <CompanyId>{ $e/Id/text() }</CompanyId>
      { $info/Name }
      <EventId>{ $ev/Id/text() }</EventId>
      <Event>{ $event-def//Name/text() }</Event>
      <Country>{ 
        if (enterprise:is-a($e, 'Investor')) then
            display:gen-name-for('ISO3Countries', $info/Address/ISO3CountryRef, 'en')
        else
            display:gen-name-for('Countries', $info/Address/Country, 'en') }</Country>
      <Acronym>
        {
        if (enterprise:is-a($e, 'Investor')) then
            "Investor"
        else
         let $tag :=  if ($event-def/Template/@ProjectKeyTag) then string($event-def/Template/@ProjectKeyTag) else 'Acronym'
         let $proj-key := $ev//*[local-name() eq $tag]
         return  
           if ((exists($proj-key)) and (not($proj-key eq ''))) then 
             concat($e//ProjectId[. = $proj-key]/../Acronym, ' (', $proj-key, ')')
           else
             ()
        }
      </Acronym>
      <LastChange>{ display:gen-display-date($ev//Status[ValueRef = $ev/StatusHistory/CurrentStatusRef]/Date, 'en')}</LastChange>
      <Status>{ display:gen-name-for('OTF', $ev/StatusHistory/CurrentStatusRef, 'en') }</Status>
    </Users>
};

(: ======================================================================
   Returns Events(s) matching request with request timing
   ======================================================================
:)
declare function search:fetch-events ( $request as element(), $programs as xs:string*, $cache as map()? ) as element()* {
  if (count($request/*/node()) = 0 and empty($programs)) then (: empty request :)
    local:fetch-all-events($cache)
  else
    local:fetch-some-events($request, $programs, $cache)
};

(: ======================================================================
   Dumps all events in database
   ======================================================================
:)
declare function local:fetch-all-events ( $cache as map()? ) as element()* 
{
  let $events := fn:collection('/db/sites/cockpit/events')//Event
  let $enterprises := fn:collection('/db/sites/cockpit/enterprises')
  return
    for $ev in $enterprises//Enterprise//Events/Event[Data/Application]
    return local:gen-enterprise-sample($ev, $events)
};

(: ======================================================================
   Dumps a subset of enterprise filtered by criterias
   FIXME: optimize by caching WorkflowId by event ?
   ======================================================================
:)
declare function local:fetch-some-events ( $filter as element(), $programs as xs:string*, $cache as map()? ) as element()*
{
  let $funding := $filter//FundingProgramRef
  let $pid := $filter//ProjectId
  let $acronym := $filter//Acronym
  let $termination := $filter//TerminationFlagRef
  let $validity := $filter//StatusFlagRef[text() ne '2']
  let $valid := $filter//StatusFlagRef[text() eq '2']
  let $type := $filter//CompanyTypeRef
  let $events := fn:collection('/db/sites/cockpit/events')//Event
  let $enterprise := $filter//EnterpriseRef
  let $event := $filter//EventRef
  let $country := $filter/Country/Country
  let $town := $filter//Town
  let $size := $filter//SizeRef
  let $domain := $filter//DomainActivityRef
  let $market := $filter//TargetedMarketRef
  let $status := $filter//StatusRef
  let $po := $filter//ProjectOfficerRef
  let $datestart := $filter//DateOpen
  let $dateend := $filter//DateClose
  let $enterprises := fn:collection('/db/sites/cockpit/enterprises')
  let $persons := fn:collection('/db/sites/cockpit/persons')
  return
    for $ev in $enterprises//Enterprise/Events/Event[Data/Application]
    let $ent := $ev/../..
    let $ev-def := $events[Id eq $ev/Id]
    let $program := $ev-def/Programme/@WorkflowId
    let $evpid := if ($ev-def/Template/@ProjectKeyTag) then $ev//*[local-name(.) eq $ev-def/Template/@ProjectKeyTag][1]/text() else $ev/Data/Application//Acronym/text()
    let $ev-po :=
      if ($po) then
        $persons//Person[UserProfile[Remote eq $ent/Projects/Project[ProjectId eq $evpid]/ProjectOfficerKey/text()]]/Id/text()
      else
        ()
    let $info := $ev/../../Information
    let $static-proj := $ent/Projects/Project[ProjectId eq $evpid]
    let $statuses := if (empty($status)) then () else for $d in $ev//StatusHistory/Status[(ValueRef = $status) or empty($status)]/Date return substring($d, 1, 10)
    where (empty($enterprise) or $ent/Id = $enterprise)
      and (empty($pid) or $evpid = $pid)
      and (empty($acronym) or $evpid= $acronym)
      and (empty($funding) or $static-proj/Call/FundingProgramRef = $funding)
      and (empty($termination) or $static-proj//TerminationFlagRef = $termination)
      and (empty($validity) or $ent//StatusFlagRef = $validity)
      and (empty($valid) or $ent//StatusFlagRef = $valid or string-join($static-proj//StatusFlagRef, '') eq '')
      and (empty($type) or enterprise:organisation-is-a($ent, $type))
      and (empty($country) or $info//Country = $country)
      and (empty($town) or $info/Address/Town = $town)
      and (empty($size) or $info/SizeRef = $size)
      and (empty($domain) or $info/ServicesAndProductsOffered/DomainActivities/DomainActivityRef = $domain)
      and (empty($market) or $info/TargetedMarkets/TargetedMarketRef = $market)
      and (empty($event) or ($ev/Id = $event))
      and (empty($po) or ($ev-po = $po))
      and (empty($status) or ($ev/StatusHistory/CurrentStatusRef = $status))
      and (empty($datestart) or (some $date in $statuses satisfies $date ge $datestart))
      and (empty($dateend) or (some $date in $statuses satisfies $date le $dateend))
      and (empty($programs) or ($program = $programs))
    return
      local:gen-enterprise-sample($ev, $events) 
};
