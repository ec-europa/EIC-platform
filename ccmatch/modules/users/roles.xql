xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Simple Roles management :
   Handles POST <Set | Unset>(admin-system | coach)</Set | Unset>

   October 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace account = "http://oppidoc.com/ns/account" at "account.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

(:declare option exist:serialize "method=xml media-type=text/xml";:)
declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Checks submitted data is correct
   Returns an error or the empty sequence
   ======================================================================
:)
declare function local:validate-submission( $person as element()?, $data as item(), $user as xs:string* ) as element()* {
  if (empty($person)) then
    ajax:throw-error('BAD-REQUEST', ())
  else if (not($data instance of element())) then
    ajax:throw-error('VALIDATION-FORMAT-ERROR', ())
  else if (not(local-name($data) = ('Set', 'Unset'))) then
    ajax:throw-error('VALIDATION-ROOT-ERROR', local-name($data))
  else if (not($data/text() = ('admin-system', 'coach')))then
    ajax:throw-error('VALIDATION-FORMAT-ERROR', ())
  else 
    (: admin-system cannot remove the administration role from herself :)
    if ((local-name($data) eq 'Unset') and ($data/text() eq 'admin-system')) then
      if (oppidum:get-current-user() = $user) then
        if ($person/Roles/Role/FunctionRef[. = '1']) then (: FIXME: hard coded reference :)
          ()
        else
          ajax:throw-error('PROTECT-ADMIN-SYSTEM-ROLE', ())
      else
        ()
    else
      ()
};

(: ======================================================================
   Synchronizes A Person eXist-DB groups with his/her UserProfile groups
   Does nothing if the Person hasn't got a Username nor an eXist-DB login
   Returns an Ajax payload to be inserted into User management result table
   ======================================================================
:)
declare function local:synch-user-groups( $person as element() ) {
  let $login := string($person//Username)
  let $uname := concat($person/Information/Name/FirstName, ' ', $person/Information/Name/LastName)
  let $payload := person:gen-user-sample-for-mgt-table($person, 'update')
  return
    if ($login and xdb:exists-user($login)) then
      let $has := xdb:get-user-groups($login)
      let $should := account:gen-groups-for-user($person)
      return 
        (
        if ( (every $x in $has satisfies $x = $should) and (every $y in $should satisfies $y = $has) ) then
          ()
        else
          system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:change-user($login, (), $should, ())),
        let $msg := concat($uname, " (", string-join($should, ", "), ")")
        return
          ajax:report-success('PROFILE-UPDATED', $msg, $payload)
        )
    else
      ajax:report-success('PROFILE-UPDATED-WOACCESS', $uname, $payload)
};

(: ======================================================================
   Updates a user profile with a Role
   ======================================================================
:)
declare function local:add-role( $person as element(), $role-ref as xs:string ) as element()* {
  let $addition := <Role><FunctionRef>{ $role-ref }</FunctionRef></Role>
  let $profile := $person/UserProfile
  let $done := 
    if ($profile/Roles) then 
      update insert $addition into $profile/Roles
    else if ($profile) then
      update insert <Roles>{ $addition }</Roles> into $profile
    else
      update insert <UserProfile><Roles>{ $addition }</Roles></UserProfile> into $person
  return
    local:synch-user-groups($person)
};

(: ======================================================================
   Gives role to person
   ====================================================================== 
:)
declare function local:set( $person as element(), $role as xs:string ) {
  let $role-ref := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role = $role]/Id/text()
  let $role := $person/UserProfile/Roles/Role[FunctionRef eq $role-ref]
  return
    if ($role) then
      ajax:report-success('INFO', 'Nothing to change, user already own this role')
    else
      local:add-role($person, $role-ref)
  };

(: ======================================================================
   Withdraw role from person
   ====================================================================== 
:)
declare function local:unset( $person as element(), $role as xs:string ) {
  let $role-ref := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role = $role]/Id/text()
  let $deletion := $person/UserProfile/Roles/Role[FunctionRef eq $role-ref]
  return
    if ($deletion) then (
      update delete $deletion,
      local:synch-user-groups($person)
      )
    else
      ajax:report-success('INFO', 'Nothing to change, user does not own this role')
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $id := string($cmd/resource/@name)
(:let $lang := string($cmd/@lang):)
return
  if ($m = 'POST') then
    let $submitted := oppidum:get-data()
    let $person := fn:collection($globals:persons-uri)//Person[Id = $id]
    let $user :=  $person/UserProfile/(Username | Remote)
    return
      let $errors := local:validate-submission($person, $submitted, $user)
      return
        if (empty($errors)) then
          if (local-name($submitted) eq 'Set') then
            local:set($person, $submitted/text())
          else (:assumes Unset:)
            local:unset($person, $submitted/text())
        else
          $errors
  else 
    oppidum:throw-error('URI-NOT-FOUND', ())
