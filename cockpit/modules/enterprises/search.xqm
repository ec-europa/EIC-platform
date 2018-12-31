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
   Returns a Member name for display in search results list
   ====================================================================== 
:)
declare function local:gen-team-member ( $member as element() ) as xs:string {
  let $info := $member/Information
  let $name := concat($info/Name/LastName, ' ', $info/Name/FirstName)
  return
    if ($info/Function) then
      concat($name, ' (', $info/Function, ')')
    else
      $name
};

(: ======================================================================
   Generates Enterprise information fields to display in result table
   ======================================================================
:)
declare function local:gen-enterprise-sample ( $e as element(), $cache as map() ) as element() {
  let $info := $e/Information
  return
    <Users>
      { $e/Id, $info/Name }
      <Nace>{ 
        if ($info/ServicesAndProductsOffered/DomainActivities/DomainActivityRef) then
            display:gen-map-name-for('DomainActivities', $info/ServicesAndProductsOffered/DomainActivities/DomainActivityRef, $cache)
        else if (enterprise:is-a($e, 'Investor')) then
            "Investor"
        else
        ()
      }</Nace>
      { 
      $info/Address/Town,
      if (enterprise:is-a($e, 'Investor')) then
        <Country> { display:gen-name-for('ISO3Countries', $info/Address/ISO3CountryRef, 'en') } </Country>
      else 
        $info/Address/Country }
      <Size>{ 
      if ($info/SizeRef) then
            display:gen-map-name-for('Sizes', $info/SizeRef, $cache)
        else if (enterprise:is-a($e, 'Investor')) then
            "Investor"
        else 
        ()
       }</Size>
      <Markets>{ display:gen-map-name-for('TargetedMarkets', $info/TargetedMarkets/TargetedMarketRef, $cache) }</Markets>
      <Team>
        {
        string-join(for $m in $e//Member
                    return local:gen-team-member($m),
                    ', ')
        }
      </Team>
    </Users>
};

(: ======================================================================
   Returns Enterprise(s) matching request with request timing
   ======================================================================
:)
declare function search:fetch-enterprises ( $request as element(), $cache as map() ) as element()* {
  if (count($request/*/*) + count($request/*[local-name(.)][normalize-space(.) != '']) = 0) then (: empty request :)
    local:fetch-all-enterprises($cache)
  else
    local:fetch-some-enterprises($request, $cache)
};

(: ======================================================================
   Dumps all enterprises in database
   ======================================================================
:)
declare function local:fetch-all-enterprises ( $cache as map() ) as element()* 
{
  for $e in fn:collection($globals:enterprises-uri)//Enterprise
  order by $e/Name
  return
    local:gen-enterprise-sample($e, $cache)
};

(: ======================================================================
   Dumps a subset of enterprise filtered by criterias
   ======================================================================
:)
declare function local:fetch-some-enterprises ( $filter as element(), $cache as map() ) as element()*
{
  let $funding := $filter//FundingProgramRef
  let $calls := $filter//CallRef
  let $funding := 
    if (empty($funding)) then
      let $callsel := globals:collection('global-information')//Selector[./Group/Selector/Option[Code = $calls]]/@Name
      return
        globals:collection('global-information')//Selector[@Name eq 'FundingPrograms']/Option[Calls eq $callsel]/Id/text()
    else
      $funding
  
  let $po := $filter//ProjectOfficerRef
  let $po :=
    if (empty($po)) then
      $po
    else
      fn:collection('/db/sites/cockpit/persons')//Person[Id = $po]/UserProfile/Remote
  let $pid := $filter//ProjectId
  let $acronym := $filter//Acronym
  let $termination := $filter//TerminationFlagRef
  let $validity := $filter//StatusFlagRef[text() ne '2']
  let $valid := $filter//StatusFlagRef[text() eq '2']
  
  let $enterprise := $filter//EnterpriseRef
  let $town := $filter//Town
  let $country := $filter//Country
  let $size := $filter//SizeRef
  let $domain := $filter//DomainActivityRef
  let $market := $filter//TargetedMarketRef
  let $type := $filter//CompanyTypeRef
  let $person := $filter//PersonKey
  return
    for $e in fn:collection($globals:enterprises-uri)//Enterprise
      [empty($pid) or ./Projects/Project/ProjectId eq $pid]
      [empty($acronym) or ./Projects/Project/ProjectId = $acronym]
      [empty($po) or ./Projects/Project/ProjectOfficerKey = $po]
      [empty($termination) or ./Projects/Project/TerminationFlagRef = $termination]
      [empty($validity) or ./Status/StatusFlagRef = $validity]
      [empty($valid) or ./Status/StatusFlagRef = $valid or string(./Status/StatusFlagRef) eq '']
      [empty($calls) or
        (./Projects/Project/Call/SMEiCallRef = $calls and '1' = $funding) or
        (./Projects/Project/Call/FTICallRef = $calls and '2' = $funding) or
        (./Projects/Project/Call/FETCallRef = $calls and '3' = $funding)]
      [empty($funding) or ./Projects/Project/Call/FundingProgramRef = $funding]
    let $info := $e/Information
    where (empty($enterprise) or $e/Id = $enterprise)
      and (empty($town) or $info/Address/Town = $town)
      and (empty($country) or $info/Address/Country/text() = $country)
      and (empty($size) or $info/SizeRef = $size)
      and (empty($domain) or $info/ServicesAndProductsOffered/DomainActivities/DomainActivityRef = $domain)
      and (empty($market) or $info/TargetedMarkets/TargetedMarketRef = $market)
      and (empty($type) or enterprise:organisation-is-a($e, $type))
      and (empty($person) or ($e//Team//PersonRef[. = $person] or $e//Team//Email[. = $person]))
    order by $info/Name
    return
      local:gen-enterprise-sample($e, $cache)
};
