xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage Enterprise entries inside the database.

   December 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace search = "http://platinn.ch/coaching/search" at "search.xqm";
import module namespace database = "http://oppidoc.com/ns/database" at "../../../excm/lib/database.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Removes Role element for a given role associated with a given region
   for every person in the list of references.
   DUPLICATE in delete.xql
   ======================================================================
:)
declare function local:remove-team-for( $team-refs as xs:string*, $role as xs:string, $region as xs:string ) {
  let $role-ref := access:get-function-ref-for-role($role)
  return
    for $ref in $team-refs
    let $role := fn:collection($globals:persons-uri)//Person[Id eq $ref]/UserProfile/Roles/Role[(FunctionRef eq $role-ref) and (RegionalEntityRef eq $region)]
    where $role
    return
      update delete $role
};

declare function local:add-team-for( $team-refs as xs:string*, $role as xs:string, $region as xs:string ) {
  let $role-ref := access:get-function-ref-for-role($role)
  return
    for $ref in $team-refs
    let $person := fn:collection($globals:persons-uri)//Person[Id eq $ref]
    let $profile := $person/UserProfile
    let $roles :=  $profile/Roles
    where $person and empty($roles/Role[(FunctionRef eq $role-ref) and (RegionalEntityRef eq $region)])
    return
      let $role := <Role><FunctionRef>{ $role-ref }</FunctionRef><RegionalEntityRef>{ $region }</RegionalEntityRef></Role>
      return
        if ($roles) then
          update insert $role into $roles
        else if ($profile) then
          update insert <Roles>{ $role }</Roles> into $profile
        else
          update insert <UserProfile><Roles>{ $role }</Roles></UserProfile> into $person
};

(: ======================================================================
   Changes user profiles in person database so that at the end only users
   referenced in team-refs have the given role associated with the given region
   ======================================================================
:)
declare function local:save-team-for( $team-refs as xs:string*, $role as xs:string, $region as xs:string ) {
  let $cur-refs := search:gen-linked-persons($role, $region)/Id/text()
  return
    (
    local:remove-team-for($cur-refs[empty(index-of($team-refs, .))], $role, $region),
    local:add-team-for($team-refs[empty(index-of($cur-refs, .))], $role, $region)
    )
};

(: ======================================================================
   Normalizes a string to compare it with another one
   TODO:
   - handle accentuated characters (canonical form ?)
   - factorize with enterprise.xql
   ======================================================================
:)
declare function local:normalize( $str as xs:string? ) as xs:string {
  upper-case(normalize-space($str))
};

(: ======================================================================
   Checks submitted region data is valid and check Acronym fields
   are unique or correspond to the submitted region in case of update ($curNo defined).
   Returns a list of error messages or the emtpy sequence if no errors.
   ======================================================================
:)
declare function local:validate-entity-submission( $submitted as element(), $curNo as xs:string? ) as element()* {
  let $key := local:normalize($submitted/Acronym/text())
  let $truth := fn:collection($globals:regions-uri)//Region[local:normalize(Acronym) eq $key]
  return (
      if ($truth) then
        if (not($curNo) or ($truth/Id != $curNo)) then
          ajax:throw-error('REGION-NAME-CONFLICT', $submitted/Acronym/text())
        else ()
      else (),
      if ($curNo and empty(fn:collection($globals:regions-uri)//Region[Id = $curNo])) then
        ajax:throw-error('UNKNOWN-REGION', $curNo)
      else ()
      )
};

(: ======================================================================
   Adds a new region record into the database
   ======================================================================
:)
  declare function local:create-entity( $cmd as element(), $submitted as element(), $lang as xs:string ) as element() {
  let $errors := local:validate-entity-submission($submitted, ())
  return
    if (empty($errors)) then
      let $res := template:do-create-resource('EEN', (), (), $submitted, ())
      return
        if (local-name($res) eq 'success') then 
          let $newkey := string($res/@key)
          return (
            local:save-team-for($submitted/Coordinators/MemberRef/text(), 'region-manager', $newkey),
            local:save-team-for($submitted/KeyAccountManagers/MemberRef/text(), 'kam', $newkey),
            (: currently as region can only be created from the search page, it is always redirect :)
            ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), 
              concat($cmd/@base-url, $cmd/@trail, '?preview=', $newkey))
            )[last()]
        else
          $res
    else
      ajax:report-validation-errors($errors)
};

(: ======================================================================
   Updates an Region record into database
   Pre-condition: Region already exists in DB
   ======================================================================
:)
declare function local:update-entity( $ref as xs:string, $region as element(), $submitted as element(), $lang as xs:string ) as element() {
  let $errors := local:validate-entity-submission($submitted, $ref)
  return
    if (empty($errors)) then
      let $res := template:do-update-resource('region', $ref, $region, (), $submitted)
      return 
        if (local-name($res) eq 'success') then ( (: update roles :)
          local:save-team-for($submitted/Coordinators/MemberRef/text(), 'region-manager', $ref),
          local:save-team-for($submitted/KeyAccountManagers/MemberRef/text(), 'kam', $ref),
          let $fresh-region := fn:collection($globals:regions-uri)//Region[Id = $ref]
          let $sample := search:gen-region-sample( $fresh-region, $lang, true())
          return
            ajax:report-success('ACTION-UPDATE-SUCCESS', (), $sample)
          )[last()]
        else
          $res
    else
      ajax:report-validation-errors($errors)
};

(: ======================================================================
   Returns region for viewing and/or editing
   ======================================================================
:)
declare function local:gen-entity( $ref as xs:string, $global as element(), $lang as xs:string, $goal as xs:string ) as element()* {
  let $region := fn:collection($globals:regions-uri)//Region[Id = $ref]
  return
    <RegionalEntity>
      {
      $global/Acronym,
      if (($goal eq 'read') and $global/NutsCodes) then
        <NutsCodes>{ string-join($global/NutsCodes/Nuts/text(), ', ') }</NutsCodes>
      else
        $global/NutsCodes,
      $global/Region,
      $region/WebSite,
      if ($goal eq 'read') then (
        <Coordinators>{ search:gen-team-for-display('region-manager', $ref) }</Coordinators>,
        <KeyAccountManagers>{ search:gen-team-for-display('kam', $ref) }</KeyAccountManagers>
        )
      else (
        <Coordinators>{ search:gen-team('MemberRef', 'region-manager', $ref) }</Coordinators>,
        <KeyAccountManagers>{ search:gen-team('MemberRef', 'kam', $ref) }</KeyAccountManagers>
        ),
      if ($region) then
        misc:unreference($region/Address)
      else
        <Address>{ misc:unreference($global/Country) }</Address>
      }
    </RegionalEntity>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $creating := ($m eq 'POST') and ($cmd/@action eq 'add')
let $ref := if ($creating) then () else string($cmd/resource/@name)
let $region := if ($ref) then
                 fn:collection($globals:regions-uri)//Region[Id eq $ref]
               else
                 ()
return
  if ($creating or $region) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      return
        if ($creating) then
          if (access:check-omnipotent-user-for('create', 'Region')) then
            local:create-entity($cmd, $submitted, $lang)
          else
            oppidum:throw-error('FORBIDDEN', ())
        else
          if (access:check-omnipotent-user-for('update', 'Region')) then
            local:update-entity($ref, $region, $submitted, $lang)
          else
            oppidum:throw-error('FORBIDDEN', ())
    else (: assumes GET :)
      local:gen-entity($ref, $region, $lang, request:get-parameter('goal', 'read'))
  else
    oppidum:throw-error('UNKNOWN-REGION', $ref)
