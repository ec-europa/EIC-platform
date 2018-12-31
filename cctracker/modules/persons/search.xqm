xquery version "3.1";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@opppidoc.fr>

   Shared database requests for members search

   January 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace search = "http://platinn.ch/coaching/search";

declare namespace httpclient = "http://exist-db.org/xquery/httpclient";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace analytics = "http://oppidoc.com/ns/analytics" at "../../../excm/modules/analytics/analytics.xqm";

(: ======================================================================
   Generates Person information fields to display in result table
   Includes an Update attribute flag if update is true()
   TODO: include Country fallback to first Case enterprise country for coach
   or to EEN Entity country for KAM/Coord ?
   ======================================================================
:)
declare function search:gen-person-sample ( $person as element(), $country as xs:string?, $role-ref as xs:string?, $lang as xs:string, $update as xs:boolean ) as element() {
  let $e := fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[Id = $person/EnterpriseRef/text()]
  (:let $een-coordinator := if ($role-ref) then $role-ref else access:get-function-ref-for-role('region-manager'):)
  return
    <Person>
      {(
        if ($update) then attribute  { 'Update' } { 'y' } else (),
        $person/(Id | Name | Contacts),
        if ($country) then
          <Country>{ $country }</Country>
        else if ($person/Country) then
          <Country>{ display:gen-name-for('Countries', $person/Country, $lang) }</Country>
        else if ($e/Address/Country) then (: defaults to enterprise's country :)
          <Country>{ display:gen-name-for('Countries', $e/Address/Country, $lang) }</Country>
        else
          (),
        if ($e) then
          <EnterpriseName>{$e/Name/text()}</EnterpriseName>
        else
         ()
        (: extra information to show EEN Entity in case coordinator :)
        (:if ($person/UserProfile/Roles/Role[FunctionRef/text() = $een-coordinator]) then
                  misc:gen_display_name($person/UserProfile/Roles/Role[FunctionRef/text() = $een-coordinator]/RegionalEntityRef, 'RegionalEntityName')
                else
                  ():)
      )}
    </Person>
};

(: ======================================================================
   Generates Person information fields to display in result table
   Includes an Update attribute flag if update is true()
   TODO: include Country fallback to first Case enterprise country for coach
   or to EEN Entity country for KAM/Coord ?
   ======================================================================
:)
declare function search:gen-person-sample ( $person as element(), $role-ref as xs:string?, $lang as xs:string, $update as xs:boolean ) as element() {
  let $e := fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[Id = $person/EnterpriseRef/text()]
  (:let $een-coordinator := if ($role-ref) then $role-ref else access:get-function-ref-for-role('region-manager'):)
  return
    <Person>
      {(
        if ($update) then attribute  { 'Update' } { 'y' } else (),
        $person/(Id | Name | Contacts),
        if ($person/Country) then
          <Country>{ display:gen-name-for('Countries', $person/Country, $lang) }</Country>
        else if ($e/Address/Country) then (: defaults to enterprise's country :)
          <Country>{ display:gen-name-for('Countries', $e/Address/Country, $lang) }</Country>
        else
          (),
        if ($e) then
          <EnterpriseName>{$e/Name/text()}</EnterpriseName>
        else
         ()
        (: extra information to show EEN Entity in case coordinator :)
        (:if ($person/UserProfile/Roles/Role[FunctionRef/text() = $een-coordinator]) then
                  misc:gen_display_name($person/UserProfile/Roles/Role[FunctionRef/text() = $een-coordinator]/RegionalEntityRef, 'RegionalEntityName')
                else
                  ():)
      )}
    </Person>
};

(: ======================================================================
   Returns community member(s) matching request
   FIXME: hard-coded function refs -> access:get-function-ref-for-role('xxx')
   ======================================================================
:)
declare function search:fetch-persons ( $request as element() ) as element()* {
  let $person := $request/Persons/PersonRef/text()
  let $country := $request//Country
  let $function := $request/Functions/FunctionRef/text()
  let $enterprise := $request/Enterprises/EnterpriseRef/text()
  let $region-role-ref := access:get-function-ref-for-role("region-manager")
  let $omni := access:check-omnipotent-user-for('update', 'Person')
  let $uid := if ($omni) then () else access:get-current-person-id()
  return
    <Results>
      <Persons>
        {(
        if ($omni) then attribute { 'Update' } { 'y' } else (),
        if (empty($country)) then
          (: classical search :)
          for $p in  fn:collection($globals:persons-uri)//Person[empty($person) or Id/text() = $person]
          let $id := $p/Id/text()
          where (empty($function) or $p/UserProfile/Roles/Role/FunctionRef = $function)
            and (empty($enterprise) or $p/EnterpriseRef = $enterprise)
          order by $p/Name/LastName
          return
            search:gen-person-sample($p, $region-role-ref, 'en', not($omni) and $uid eq $p/Id/text())
            (: optimization for : not($omni) and access:check-person-update-at-least($uid, $person) :)
        else
          (: optimized search for search by country :)
          let $region-refs :=
            fn:collection($globals:regions-uri)//Region[Country = $country]/Id/text()
          let $with-country-refs :=  fn:collection($globals:persons-uri)//Person[Country = $country]/Id[empty($person) or . = $person]
          (: extends to coaches having coached in one of the target country :)
          let $by-coaching-refs := distinct-values(
            fn:collection($globals:projects-uri)//Project[Information/Beneficiaries/*/Address/Country = $country]//ResponsibleCoachRef[not(. = $with-country-refs)]
            )
          (: extends to KAM and KAMCO from the target country :)
          let $by-region-refs := distinct-values(
             fn:collection($globals:persons-uri)//Person[.//Role[FunctionRef = ('3', '5')][RegionalEntityRef = $region-refs]]/Id[not(. = $with-country-refs) and not(. = $by-coaching-refs)][empty($person) or Id/text() = $person]
            )
          return (
            for $p in  fn:collection($globals:persons-uri)//Person[Id = $with-country-refs]
            where (empty($function) or $p/UserProfile/Roles/Role/FunctionRef = $function)
              and (empty($enterprise) or $p/EnterpriseRef = $enterprise)
            return
              search:gen-person-sample($p, (), $region-role-ref, 'en', not($omni) and $uid eq $p/Id/text()),
            for $p in  fn:collection($globals:persons-uri)//Person[Id = ($by-coaching-refs)]
            where (empty($person) or $p/Id = $person)
              and (empty($function) or $p/UserProfile/Roles/Role/FunctionRef = $function)
              and (empty($enterprise) or $p/EnterpriseRef = $enterprise)
            return
              search:gen-person-sample($p, 'C', $region-role-ref, 'en', not($omni) and $uid eq $p/Id/text()),
            for $p in  fn:collection($globals:persons-uri)//Person[Id = ($by-region-refs)]
            where (empty($function) or $p/UserProfile/Roles/Role/FunctionRef = $function)
              and (empty($enterprise) or $p/EnterpriseRef = $enterprise)
            return
              search:gen-person-sample($p, 'E', $region-role-ref, 'en', not($omni) and $uid eq $p/Id/text())
            )
        )}
      </Persons>
    </Results>
};


(: ======================================================================
   Generates list of Coach model for given service
   The list may be optionaly reduced to a given set of persons or to a single country
   ======================================================================
:)
declare function local:gen-coaches-sample ( $ref as xs:string, $coach-role-ref as xs:string, $person as xs:string*, $country as xs:string? ) {
  for $p in  fn:collection($globals:persons-uri)//Person
  let $id := $p/Id/text()
  where (empty($person) or $id = $person)
        and $p//Role[(FunctionRef = $coach-role-ref) and ((($ref eq '-1') and empty(ServiceRef)) or (ServiceRef eq $ref))]
        and (
            empty($country)
            or ($p/Country = $country)
            or (
               empty($p/Country)
               and
                 (
                 fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[Id = $p/EnterpriseRef]/Address/Country = $country)
                 or
                 fn:collection($globals:projects-uri)//Project[.//ResponsibleCoachRef eq $id][Information/Beneficiaries/*/Address/Country = $country]
                 )
            )
  order by $p/Name/LastName
  return
    <Coach>
      {(
      attribute { '_Display' } { concat($p/Name/FirstName, ' ', $p/Name/LastName) },
      $p/Id/text()
      )}
    </Coach>
};

(: ======================================================================
   Generates Service (aka Coaches) fields to display in result table
   ======================================================================
:)
declare function search:gen-service-sample ( $ref as xs:string, $country as element()*, $person as xs:string*, $role-ref as xs:string?, $lang as xs:string, $update as xs:boolean ) as element() {
  let $coach-role-ref := if ($role-ref) then $role-ref else access:get-function-ref-for-role('coach')
  return
    <Service>
      { if ($update) then attribute  { 'Update' } { 'y' } else () }
      <Id>{ $ref }</Id>
      {(
      if ($ref eq '-1') then
        <Name>w/o service</Name>
      else
        fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'Services']/Option[Id eq $ref ]/Name,
      if (empty($country)) then
        local:gen-coaches-sample($ref, $coach-role-ref, $person, ())
      else
        for $c in $country
        return
          <Country Name="{ display:gen-name-for('Countries', $c, 'en') }">
            { local:gen-coaches-sample($ref, $coach-role-ref, $person, $c) }
          </Country>
      )}
    </Service>
};

(: ======================================================================
   Returns Coach(es) matching request grouped by Service
   TODO : for $ref in ($service, "dangling" or -1)
   ======================================================================
:)
declare function search:fetch-coaches-LEGACY ( $request as element() ) as element()* {
  let $coach-role-ref := access:get-function-ref-for-role('coach')
  let $person := $request/Persons/PersonRef/text()
  let $service :=
    if ($request//ServiceRef) then
      $request/Services/ServiceRef/text()
    else (: all services and dangling coaches :)
      (
      fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'Services']/Option/Id/text(),
      '-1'
      )
  let $country := $request//Country
  let $omni := access:check-omnipotent-user-for('update', 'Service')
  return
    <Results>
      {
        if ($person and empty($request//ServiceRef)) then (: request targeted at name, do not show empty services :)
          attribute { 'Services' } { 'hideIfEmpty' }
        else
          ()
      }
      <Coaches>
        {
        for $ref in $service
        return search:gen-service-sample($ref, $country, $person, $coach-role-ref, 'en', $omni)
        }
      </Coaches>
    </Results>
};

(: ======================================================================
   Prepares search by criteria request to send to Coach Match from submitted criteria
   ====================================================================== 
:)
declare function local:gen-search-by-criteria ( $request as element() ) as element() {
  <Search>
    {
    services:get-key-for('ccmatch-public', 'ccmatch.search'),
    <SearchByCriteria Accepted="XML">
      { $request/* }
    </SearchByCriteria>
    }
  </Search>
};

(: ======================================================================
   Queries Coach Match search by criteria service
   Returns JSON Ajax response
   ====================================================================== 
:)
declare function search:fetch-coaches ( $request as element() ) {
   let $response :=  analytics:save-request(
                       'coach-standalone-search', $request, 'Coaches', 20,
                       services:post-to-service(
                         'ccmatch-public', 'ccmatch.search',
                         local:gen-search-by-criteria($request),
                         ("200")
                         )
                       )
   return
    if (local-name($response) ne 'error') then (
      $response//httpclient:body/success,
      util:declare-option('exist:serialize', 'method=json media-type=application/json')
      )
    else
      $response
};
