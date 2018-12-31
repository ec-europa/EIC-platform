xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Authors: 
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   CRUD controller to manage Person entries inside the database.

   December 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace search = "http://platinn.ch/coaching/search" at "search.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";
import module namespace persons = "http://oppidoc.com/ns/cctracker/persons" at "persons.xqm";
import module namespace database = "http://oppidoc.com/ns/database" at "../../../excm/lib/database.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Normalizes a string to compare it with another one
   TODO: handle accentuated characters (canonical form ?)
   ======================================================================
:)
declare function local:normalize( $str as xs:string? ) as xs:string {
  upper-case(normalize-space($str))
};

(: ======================================================================
   Checks submitted person data is valid
   Validate for creation if curNo is empty or for updating otherwise
   Returns a list of error messages or the emtpy sequence if no errors
   ======================================================================
:)
declare function local:validate-person-submission( $data as element(), $curNo as xs:string? ) as element()* {
  (: 1. Submission with remote login must be complete (realm and key) :)
  let $rem := $data/External/Remote/text()[. ne '']
  let $rel := $data/External/Realm/text()[. ne '']
  return
    if ((exists($rem) and empty($rel)) or (empty($rem) and exists($rel))) then
      oppidum:throw-error('REMOTE-PROFILE-MISSING-DATA', ())
    else
      (: 2. e-mail and login key unicity :)
      let $email-key := local:normalize($data/Contacts/Email/text())
      let $remote-key := if (exists($rem)) then local:normalize($rem) else ()
      let $remote-mail := fn:doc($globals:remotes-uri)//Remote[Realm eq 'ECAS'][local:normalize(Mail) eq $email-key]
      return (: nests tests for optimization :)
        if (exists($remote-mail)) then (: 2.1 check overwritting a pre-registered user's e-mail :)
          let $duplicate := $remote-mail[1]
          return
            ajax:throw-error('PERSON-EMAIL-CONFLICT', ('pre-registered', $duplicate/Mail))
        else (: 2.2 check overwritting another pre-registered user's login key:)
          let $remote-login := fn:doc($globals:remotes-uri)//Remote[Realm eq 'ECAS'][local:normalize(Key) eq $remote-key]
          return
            if (exists($remote-login)) then 
              let $duplicate := $remote-login[1]
              return
                ajax:throw-error('PERSON-KEY-CONFLICT', ('pre-registered', $duplicate/Key))
            else (: 2.3 check overwritting another local user's e-mail :)
              let $local-mail := fn:collection($globals:persons-uri)//Person[local:normalize(Contacts/Email) eq $email-key]
              return
                if (exists($local-mail) and ((empty($curNo)) or not($curNo = $local-mail/Id))) then
                  let $duplicate := if (empty($curNo)) then $local-mail[1] else $local-mail[Id ne $curNo][1]
                  return
                    ajax:throw-error('PERSON-EMAIL-CONFLICT', (display:gen-person-name($duplicate/Id, 'en'), $duplicate/Contacts/Email))
                else (: 2.4 check overwritting another local CAS login key:)
                  let $local-login := fn:collection($globals:persons-uri)//Person[local:normalize(UserProfile/Remote[string(@Name) eq 'ECAS']) eq $remote-key]
                  return
                    if (exists($local-login) and ((empty($curNo)) or not($curNo = $local-login/Id))) then 
                      let $duplicate := if (empty($curNo)) then $local-login[1] else $local-login[Id ne $curNo][1]
                      return
                        ajax:throw-error('PERSON-KEY-CONFLICT', (display:gen-person-name($duplicate/Id, 'en'), $duplicate/UserProfile/Remote[string(@Name) eq 'ECAS']))
                    else 
                      ()
};

(: ======================================================================
   Regenerates the UserProfile for the current submitted person whether s/he exists or not
   Interprets current request "f" parameter to assign "kam" or "coach" function on the fly
   FIXME: 
   - access control layer before promoting a kam or coach ?
   - ServiceRef and / or RegionalEntityRef should be upgraded on workflow transitions
   ======================================================================
:)
declare function local:gen-user-profile-for-writing( $profile as element()?, $external as element()? ) {
  let $function := request:get-parameter("f", ())
  let $fref := access:get-function-ref-for-role($function)
  let $remote := 
    if (exists($external/Realm[. ne '']) and exists($external/Remote[. ne ''])) then
      <Remote Name="{ $external/Realm/text() }">{ $external/Remote/text() }</Remote>
    else
      ()
  return
    if ($fref and ($function = ('kam', 'coach'))) then (: DEPRECATED ??? :)
      if ($profile) then 
        if ($profile/Roles/Role/FunctionRef[. eq $fref]) then (: simple persistence :)
          <UserProfile>{ $profile/*[not(local-name(.) = 'Remote')], $remote }</UserProfile>
        else
          <UserProfile>
            <Roles>
              { $profile/Roles/Role }
              <Role><FunctionRef>{ $fref }</FunctionRef></Role>
            </Roles>
            { $remote }
          </UserProfile>
      else
          <UserProfile>
            <Roles><Role><FunctionRef>{ $fref }</FunctionRef></Role></Roles>
            { $remote }
          </UserProfile>
    else if (access:check-omnipotent-user-for('create', 'Person')) then (: TODO: for('create', 'Realms') ? :)
      <UserProfile>
        { 
        $profile/*[not(local-name(.) = 'Remote')], 
        $remote
        }
      </UserProfile>
    else
      $profile (: a user editing his person record cannot change his profile :)
};

(: ======================================================================
   Reconstructs a Person record from current Person data and from new submitted
   Person data. Note that current Person may be the empty sequence in case of creation.
   Persists UserProfile element if present.
   ======================================================================
:)
declare function local:gen-person-for-writing( $current as element()?, $new as element(), $index as xs:integer? ) {
  <Person>
    {(
    if ($current) then (
      $current/@PersonId,
      $current/Id 
      )
    else 
      <Id>{$index}</Id>,
    $new/Sex,
    $new/Civility,
    <Name>
      {$new/Name/*}
      {if ($current) then $current/Name/SortString else (<SortString>{$current/Name/LastName}</SortString>)}
    </Name>,
    $new/Country,
    $new/EnterpriseRef,
    $new/Function,
    $new/Contacts,
    $new/Photo,
    local:gen-user-profile-for-writing($current/UserProfile, $new/External)
    )}
  </Person>
};

(: ======================================================================
   Inserts a new Person inside the database (creation or importation)
   NOTE: currently Id is computed, maybe that would be better to use a @LastId counter
   ======================================================================
:)
declare function local:create-person( $cmd as element(), $data as element(), $format as xs:string ) {
  let $newkey := 
    max(for $key in fn:collection($globals:persons-uri)//Person/Id
    return if ($key castable as xs:integer) then number($key) else 0) + 1
  let $person := local:gen-person-for-writing((), $data, $newkey)
  return (
    persons:create-person-in-collection($person, $newkey),
    if ($format eq 'redirect') then (: Ajax redirection protocol :)
      ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), concat($cmd/@base-url, $cmd/@trail, '?preview=', $newkey))
    else if ($format eq 'json') then (: Ajax JSON table protocol :)
      let $persists := request:get-parameter('persists', ()) (: foregin table row key :)
      return (
        util:declare-option("exist:serialize", "method=json media-type=application/json"),
        ajax:report-success('ACTION-CREATE-SUCCESS', (), person:gen-import-sample-for-mgt-table($person, $persists))
        )
    else (: Ajax XML table protocol or Ajax HTML table protocol :)
      let $from := request:get-parameter('from', ())
      let $result := 
        <Response Status="success">
          <Payload>
            {
            if ($from) then attribute Key { $from } else (),
            $data/Name/LastName,
            $data/Name/FirstName,
            $data/Contacts/Email,
            $data/Country,
            <Value>{$newkey}</Value>
            }
          </Payload>
        </Response>
      return
        ajax:report-success('ACTION-CREATE-SUCCESS', (), $result)
    )[last()]
};

declare function local:validate-and-create-person( $cmd as element(), $format as xs:string ) {
  let $data := oppidum:get-data()
  let $errors := local:validate-person-submission($data, ())
  return
    if (empty($errors)) then
      local:create-person($cmd, $data, $format)
    else
      ajax:report-validation-errors($errors)
};

(: ======================================================================
   Updates a Person model into database
   Returns Person model including the update flag (since the user must be allowed)
   ======================================================================
:)
declare function local:update-person( $current as element(), $data as element(), $format as xs:string ) {
  (
    template:update-resource('person', $current, $data),
    if ($format eq 'json') then (: Ajax JSON table protocol :)
      let $table := request:get-parameter('table', ())
      let $p := fn:collection($globals:persons-uri)//Person[Id eq $current/Id]
      return (
        util:declare-option("exist:serialize", "method=json media-type=application/json"),
        ajax:report-success('ACTION-UPDATE-SUCCESS', (), person:gen-update-sample-for-mgt-table($p))
        )
    else (: Ajax XML table protocol or Ajax HTML table protocol :)
      let $p := fn:collection($globals:persons-uri)//Person[Id eq $current/Id]
      let $result := search:gen-person-sample($p, (), 'en', true())
      return
        ajax:report-success('ACTION-UPDATE-SUCCESS', (), $result)
    )[last()]
};

(: ======================================================================
   Utility to generate remote login information (Key, Realm) for person
   ====================================================================== 
:)
declare function local:gen-remote( $person ) as element()? {
  <External>
    <Remote>{ $person/UserProfile/Remote/text() }</Remote>
    <Realm>{ string($person/UserProfile/Remote/@Name) }</Realm>
  </External>
};

(: ======================================================================
   Returns a Person model for a given goal
   Note EnterpriseRef -> EnterpriseName for modal window
   ======================================================================
:)
declare function local:gen-person( $person as element(), $lang as xs:string, $goal as xs:string ) as element()* {
  if ($goal = 'read') then
    (: serves both EnterpriseName for the persons/xxx.modal in /stage
       and EnterpriseRef for persons/xxx.blend view in /persons   :)
    let $entname := display:gen-enterprise-name($person/EnterpriseRef, $lang)
    let $roles := 
      <Roles>
      {
      for $r in $person/UserProfile/Roles/Role
      let $services := display:gen-name-for('Services', $r/ServiceRef, $lang)
      let $entities := display:gen-name-for-regional-entities( $r/RegionalEntityRef, $lang)
      return 
        (
        <Function>{ display:gen-function-name($r/FunctionRef, $lang) }</Function>,
        if ($services or $entities) then 
          <Name>
            { string-join(($services, $entities)[. ne ''], ", ") }
          </Name>
        else
          <Name/>
        )
      }
      </Roles>
    return
      <Person>
        { $person/(Id | Sex | Civility | Name | Photo | Contacts) }
        { misc:unreference($person/Country) }
        <EnterpriseRef>{$entname}</EnterpriseRef>
        <EnterpriseName>{$entname}</EnterpriseName>
        {$person/Function}
        { if (count($roles/Function) > 0) then $roles else () }
        { local:gen-remote($person) }
      </Person>
  else if ($goal = 'update') then
    <Person>
      { 
      $person/(Sex | Civility | Name | Country | EnterpriseRef | Function | Contacts | Photo),
      local:gen-remote($person)
      }
    </Person>
  else
    ()
};

declare function local:POST-create-person( $cmd as element(), $format as xs:string ) {
  if (access:check-omnipotent-user-for('create', 'Person')) then
    local:validate-and-create-person($cmd, $format)
  else
    oppidum:throw-error('FORBIDDEN', ())
};

declare function local:POST-update-person( $cmd as element(), $ref as xs:string, $format as xs:string ) {
  let $person := if ($ref) then fn:collection(oppidum:path-to-ref-col())//Person[Id = $ref] else ()
  return
    if ($person) then
      if (access:check-person-update($person)) then
        let $data := oppidum:get-data()
        let $errors := local:validate-person-submission($data, $ref)
        return
          if (empty($errors)) then
            local:update-person($person, $data, $format)
          else
            ajax:report-validation-errors($errors)
      else
        oppidum:throw-error('FORBIDDEN', ())
    else
      oppidum:throw-error("PERSON-NOT-FOUND", ())
};

declare function local:GET-person( $cmd as element(), $ref as xs:string ) {
  let $lang := string($cmd/@lang)
  let $person := if ($ref) then fn:collection(oppidum:path-to-ref-col())//Person[Id = $ref] else ()
  return
    if ($person) then
      (: access control done at mapping level :)
      local:gen-person($person, $lang, request:get-parameter('goal', 'read'))
    else
      oppidum:throw-error("PERSON-NOT-FOUND", ())
};

(: MAIN ENTRY POINT - CONTROLLER ROUTING :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $target := string($cmd/resource/@name)
let $format := request:get-parameter('format', 'xml')
return
  if ($m eq 'POST') then
    if ($cmd/@action eq 'add') then  (: POST persons/add[?next=redirect][.xml][?format=json][?from] :)
      if (request:get-parameter('next', ()) eq 'redirect') then
        local:POST-create-person($cmd, 'redirect')
      else
        local:POST-create-person($cmd, $format)
    else (: POST persons/{id}[.xml][?format=json][?table] :)
      local:POST-update-person($cmd, $target, $format)
  else (: assumes GET profiles/{id} :)
    local:GET-person($cmd, $target)
