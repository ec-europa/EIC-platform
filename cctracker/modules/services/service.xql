xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage Service team composition

   January 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace search = "http://platinn.ch/coaching/search" at "../persons/search.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   TODO: dangling service
   ======================================================================
:)
declare function local:gen-linked-persons ( $role as xs:string, $service as element()? ) as element()* {
  let $role-ref := access:get-function-ref-for-role($role)
  let $ref := $service/Id/text()
  return
    fn:collection($globals:persons-uri)//Role[(FunctionRef eq $role-ref) 
      and ((empty($service) and empty(ServiceRef)) or (ServiceRef eq $ref))]/ancestor::Person
};

declare function local:gen-team ( $role as xs:string, $tag as xs:string, $service as element()? ) as element()* {
  for $p in local:gen-linked-persons ($role, $service)
  order by $p/Name/LastName
  return
    element { $tag } {(
      attribute { '_Display' } { concat($p/Name/LastName, ' ', $p/Name/FirstName) },
      $p/Id/text()
    )}
};

declare function local:gen-team-for-display ( $role as xs:string, $service as element()? ) as xs:string {
  let $team := local:gen-linked-persons ($role, $service)
  return
    if (empty($team)) then
      ''
    else
      string-join(
        for $p in $team
        order by $p/Name/LastName
        return
            concat($p/Name/LastName, ' ', $p/Name/FirstName),
        ', '
      )
};

(: ======================================================================
   Removes Role element for a given role associated with a given service
   for every person in the list of references.
   Supposed to work for coach role (i.e. roles with a ServiceRef)
   ======================================================================
:)
declare function local:remove-team-for( $team-refs as xs:string*, $role as xs:string, $service-ref as xs:string ) {
  let $role-ref := access:get-function-ref-for-role($role)
  return
    for $ref in $team-refs
    let $role := fn:collection($globals:persons-uri)//Person[Id eq $ref]/UserProfile/Roles/Role[(FunctionRef eq $role-ref) and ((($service-ref eq '-1') and empty(ServiceRef)) or (ServiceRef eq $service-ref))]
    where $role
    return
      if (count($role/ServiceRef) > 1) then
        update delete $role/ServiceRef[. eq $service-ref]
      else if (count($role/ServiceRef) = 1) then
        update delete $role/ServiceRef (: put into w/o service state :)
      else (: removing from coach role w/o service state  :)
        update delete $role
};

declare function local:add-team-for( $team-refs as xs:string*, $role as xs:string, $service-ref as xs:string ) {
  let $role-ref := access:get-function-ref-for-role($role)
  return
    for $ref in $team-refs
    let $person := fn:collection($globals:persons-uri)//Person[Id eq $ref]
    let $profile := $person/UserProfile
    let $roles :=  $profile/Roles
    where $person and empty($roles/Role[(FunctionRef eq $role-ref) and (ServiceRef eq $service-ref)])
    return
      let $role := $roles/Role[FunctionRef eq $role-ref]
      let $service := if ($service-ref ne '-1') then <ServiceRef>{ $service-ref }</ServiceRef> else ()
      return 
        if ($role) then (: use pre-existing Role element :)
          if ($service) then
            update insert $service into $role
          else
            (: remove coach from all services to put him into the w/o service state :)
            update delete $role/ServiceRef
        else
          let $role := <Role><FunctionRef>{ $role-ref }</FunctionRef>{ $service }</Role>
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
   referenced in team-refs have the given role associated with the given service
   ======================================================================
:)
declare function local:save-team-for( $team-refs as xs:string*, $role as xs:string, $service as element()?, $service-ref as xs:string) {
  let $cur-refs := local:gen-linked-persons($role, $service)/Id/text()
  return
    (
    local:remove-team-for($cur-refs[empty(index-of($team-refs, .))], $role, $service-ref),
    local:add-team-for($team-refs[empty(index-of($cur-refs, .))], $role, $service-ref)
    )
};

(: ======================================================================
   Checks submitted service data is valid
   ======================================================================
:)
declare function local:validate-service-submission( $data as element(), $curNo as xs:string? ) as element()* {
  ()
};

(: ======================================================================
   Updates a Service team into database
   ======================================================================
:)
declare function local:update-service( $service as element()?, $submitted as element(), $lang as xs:string ) as element() {
  let $service-ref := if ($service) then $service/Id/text() else '-1'
  return
    (
    local:save-team-for($submitted/Coaches/CoachRef/text(), 'coach', $service, $service-ref),
    let $result := search:gen-service-sample($service-ref, (), (), (), 'en', true())
    return
      ajax:report-success('ACTION-UPDATE-SUCCESS', (), $result)
    )
};
  
(: ======================================================================
   Returns the Service model for display or editing
   Pre-condition: service exists
   ======================================================================
:)
declare function local:gen-service( $service as element()?, $lang as xs:string, $goal as xs:string ) as element()* {
  <Service>
    <Name>
      {
      if ($service) then
        display:gen-name-for('Services', $service/Id, 'en') 
      else
        'w/o service'
      }
    </Name>
    <Coaches>
      {
      if ($goal eq 'read') then
        local:gen-team-for-display('coach', $service)
      else
        local:gen-team('coach', 'CoachRef', $service)
      }
    </Coaches>
  </Service>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $ref := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
let $service := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'Services']/Option[Id eq $ref ]
return
  if ($service or ($ref eq '-1')) then
    (: ************************* :)
    (: **** POST Controller **** :)
    (: ************************* :)
    if ($m = 'POST') then
      if (access:check-omnipotent-user-for('update', 'Service')) then
        let $submitted := oppidum:get-data()
        return
          let $errors := local:validate-service-submission($submitted, $ref)
          return
            if (empty($errors)) then
              local:update-service($service, $submitted, $lang)
            else
              ajax:report-validation-errors($errors)
      else
        oppidum:throw-error('FORBIDDEN', ())
    (: ************************* :)
    (: **** GET Controller  **** :)
    (: ************************* :)
    else
      let $goal := request:get-parameter('goal', 'read')
      return
        local:gen-service($service, $lang, $goal)
  else 
    oppidum:throw-error("URI-NOT-FOUND", ())
    
