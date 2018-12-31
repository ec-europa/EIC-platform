xquery version "3.1";
(: ------------------------------------------------------------------
   SMEIMKT SME Dashboard application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   User account management

   Since 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../../xcm/lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:persons := globals:collection('persons-uri');
declare variable $local:enterprises := globals:collection('enterprises-uri');

(: ======================================================================
   Generates an in-memory cache to speed up page rendering by reducing
   the amount of database lookup operations
   ======================================================================
:)
declare function local:gen-cache() as map() {
  display:gen-map-for(('Functions'), 'en')
};

(: ======================================================================
   Return Name element if non empty or fake a Name to generate a name 
   string in view layer
   ====================================================================== 
:)
declare function local:gen-name-default( $name as element()? ) as element() {
  if ($name) then 
    $name
  else
    <Name><LastName>?</LastName></Name>
};

(: ======================================================================
   Generate aggregated data for the different person memberships
   ====================================================================== 
:)
declare function local:gen-personalities( $person as element(), $cache as map() ) {
  let $pid := $person/Id
  let $pending-admissions := $person//AdmissionKey[not(parent::Role/EnterpriseRef)]
  return
    <Personalities>
      {
      for $role in $person//Roles/Role[EnterpriseRef]
      return
        <Function>{ display:gen-map-name-for('Functions', $role/FunctionRef, $cache ) }</Function>,
      for $role in $person//Roles/Role[empty(EnterpriseRef)]
      return
        <Function>{ display:gen-map-name-for('Functions', $role/FunctionRef, $cache ) }</Function>,
      for $enterprise in $local:enterprises//Enterprise[Team//PersonRef eq $pid]
      let $cie-name := $enterprise/Information/ShortName
      let $key := $enterprise/Id
      let $member := $enterprise/Team//Member[PersonRef eq $pid]
      let $info := fn:head($member)/Information (: sanity check : use 1st in case of duplicates :)
      return
        <AsMember>
          <Company Id="{ $enterprise/Id }">
            {
            if ($cie-name) then
              $cie-name/text()
            else
              $enterprise/Information/Name/text()
            }
          </Company>
          {
          local:gen-name-default($info/Name),
          $info/Contacts/Email
          }
        </AsMember>,
      for $admission in fn:collection($globals:admissions-uri)//Admission[Id eq $pending-admissions]
      let $cie-name := $admission/CompanyProfile/CompanyName
      let $info := $admission/ParticipantInformation
      return
        <AsMember>
          <Company>{ $cie-name/text() }</Company>
          <Name>
            {
            $info/FirstName,
            $info/LastName
            }
          </Name>
          { $info/Email }
        </AsMember>,
      if (exists($person/Information)) then
        <Omni>
          <Company>unaffiliated</Company>
          {
          local:gen-name-default($person/Information/Name),
          $person/Information/Contacts/Email
          }
        </Omni>
      else
        (),
      (: spot anomalies - FunctionRef w/o EnterpriseRef :)
      (: TODO: use @Scope:)
      if ($person//Roles/Role[FunctionRef = ('3', '4', '7') and empty(EnterpriseRef)]) then
        <AsMember>
          <Company>NOREF</Company>
          { local:gen-name-default(()) }
        </AsMember>
      else
        ()
      (: spot anomalies - TODO: FunctionRef with wrong EnterpriseRef - very costly ! :)
      (: spot anomalies - TODO: pending investor AdmissionKey :)
    }
    </Personalities>
};

(: ======================================================================
   Returns the list of user with their account information
   ======================================================================
:)
declare function local:gen-users-for-viewing() as element()* {
  let $cache := local:gen-cache()
  return
  <Persons Date="{ substring(string(current-dateTime()), 1, 10) }">
  {
  for $p in $local:persons//Person
  let $eulogin := $p//Remote[@Name eq 'ECAS']
  return
    <Person>
      {
      $p/(Id | UserProfile/Email[@Name eq 'ECAS']),
      if ($eulogin/text()) then $eulogin else (),
      local:gen-personalities($p, $cache)
    }
    </Person>
  }
  </Persons>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $name := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
return
  if ($m = 'POST') then
    let $data := request:get-data()
    return
      ()
  else (: assumes GET :)
    local:gen-users-for-viewing()
