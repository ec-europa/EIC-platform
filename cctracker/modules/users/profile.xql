xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Authors: 
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   CRUD controller to manage roles in user profiles (UserProfile element)

   Profiles are attached to a Person element for permanent registered users
   and to a Remote element for remote pre-registered users

   Profiles should be edited using the profile formular (see formulars/profile.xml)

   April 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "account.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

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
   Utility to display a meaningful remote name after creation or updating
   ====================================================================== 
:)
declare function local:gen-remote-name-for-display( $remote as element() ) as xs:string {
  let $should := account:gen-groups-for-user($remote)
  return concat($remote/Key, " (", string-join($should, ", "), ")")
};

(: ======================================================================
   Validates a remote profile submission for creation or update.
   Remote profiles are for pre-registering users in remotes.
   @param The remote element to be updated if validation is for an update
   @return An error or the empty sequence
   ======================================================================
:)
declare function local:validate-remote-submission( $data as item()?, $model as element()? ) as element()* {
  let $errors := local:validate-profile-submission($data, ())
  let $eMail := local:normalize($data//Mail)
  let $key := local:normalize($data//Key)
  let $realm := $data//Realm
  return
    if (exists($errors)) then
      $errors
      else if (empty($data//Key) or empty($data//Mail)) then
      ajax:throw-error('WRONG-SUBMISSION', ())
    else if (exists(fn:collection($globals:persons-uri)//Person[local:normalize(Contacts/Email) eq $eMail])) then
      ajax:throw-error('LOCAL-PROFILE-DUPLICATED', $eMail)
    else if (exists(fn:collection($globals:persons-uri)//Person[local:normalize(UserProfile/Remote[@Name eq $realm]) eq $key])) then
      ajax:throw-error('LOCAL-PROFILE-DUPLICATED', $key)
    else
      let $nid := if (empty($model)) then () else util:node-id($model)
      let $same-eMail := fn:doc($globals:remotes-uri)//Remote[local:normalize(Mail) eq $eMail]
      let $same-key :=  fn:doc($globals:remotes-uri)//Remote[local:normalize(Key) eq $key]
      return
        if (exists($same-eMail) and 
            (empty($model) or (some $n in $same-eMail satisfies util:node-id($n) ne $nid))) then
          ajax:throw-error('REMOTE-PROFILE-DUPLICATED', $eMail)
        else if (exists($same-key) and 
            (empty($model) or (some $n in $same-key satisfies util:node-id($n) ne $nid))) then
          ajax:throw-error('REMOTE-PROFILE-DUPLICATED', $key)
        else
          ()
};

(: ======================================================================
   Checks submitted data is correct :
   - no empty role definition (redundant with client side validation since FunctionRef mandatory)
   - no duplicated role definition
   - a Service responsible has a ServiceRef
   - a RegionalEntity director has a RegionalEntityRef
   - a Project officer has an identifier
   - admin-system cannot remove the Administration role from herself
   @return An error or the empty sequence
   ======================================================================
:)
declare function local:validate-profile-submission( $data as item()?, $userId as xs:string? ) as element()* {
  if (not($data instance of element())) then
    ajax:throw-error('VALIDATION-FORMAT-ERROR', ())
  else if (local-name($data) ne 'UserProfile') then
    ajax:throw-error('VALIDATION-ROOT-ERROR', local-name($data))
  else if ($data/Roles/Role[not(FunctionRef)] or $data/Roles/Role/FunctionRef[. eq '']) then
    ajax:throw-error('VALIDATION-PROFILE-FAILED', local-name($data))
  else if (count(distinct-values($data/Roles/Role/FunctionRef)) ne count($data/Roles/Role/FunctionRef)) then
    ajax:throw-error('VALIDATION-DUPLICATED-ROLE', ())
  else if ($data/Roles/Role/FunctionRef[. eq '2'][empty(../ServiceRef)]) then
    ajax:throw-error('ROLE-SR-WRONG-SERVICE-REF', ())    
  else if ($data/Roles/Role/FunctionRef[. eq '3'][empty(../RegionalEntityRef) or (count(../RegionalEntityRef) > 1)]) then
    ajax:throw-error('ROLE-CAD-WRONG-CA-REF', ())
  else if ($data/Roles/Role/FunctionRef[. eq '14'][empty(..//NutsRef)]) then
    ajax:throw-error('ROLE-CAD-WRONG-NUTS-REF', ())
  else if ($data/Roles/Role/FunctionRef[. eq '12'][empty(../ProjectId) or (count(../ProjectId) > 1)]) then
    ajax:throw-error('ROLE-CAD-WRONG-POID-REF', ())    
(:  else if ($data/Roles/Role/FunctionRef[. eq '4'][empty(../ServiceRef)]) then
    ajax:throw-error('ROLE-COACH-EMPTY-SERVICE-REF', ()) :)
  else if ($userId and (access:get-current-person-id() eq $userId)) then (: user self-editing :)
    (: MUST be a system administrator since only one can edit profiles :)
    if ($data/Roles/Role/FunctionRef[.='1']) then
      ()
    else
      ajax:throw-error('PROTECT-ADMIN-SYSTEM-ROLE', ())
  else
    () (: OK :)
};

(: ======================================================================
   Returns Ajax protocol to update roles column in user management table
   ====================================================================== 
:)
declare function local:make-ajax-response( $key as xs:string, $roles as element()?, $contact as xs:string?, $id as xs:string, $realm as xs:string?, $name as xs:string?, $mail as xs:string? ) {
  <Response Status="success">
    <Payload Key="{$key}">
      <Name>{ display:gen-roles-for($roles, 'en') }</Name>
      <Contact>{ $contact }</Contact>
      <Value>{ $id }</Value>
      <Realm>{ $realm }</Realm>
      <RemoteName>{ $name }</RemoteName>
      <RemoteMail>{ $mail }</RemoteMail>
    </Payload>
  </Response>
};

(: ======================================================================
   Synchronizes a Person eXist-DB groups with his/her UserProfile groups
   Does nothing if the Person hasn't got a Username nor an eXist-DB login
   Ajax response contains a payload with a Key attribute to close modal windows (see management.js)
   DEPRECATED
   ======================================================================
:)
declare function local:synch-user-groups( $person as element() ) {
  let $login := string($person//Username)
  let $uname := concat($person/Name/FirstName, ' ', $person/Name/LastName)
  let $results := local:make-ajax-response('profile', $person/UserProfile/Roles, (), $person/Id, (), (), ())
  return
    if ($login and sm:user-exists($login)) then
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
          ajax:report-success('PROFILE-UPDATED', $msg, $results)
        )
    else
      ajax:report-success('PROFILE-UPDATED-WOACCESS', $uname, $results)
};

(: ======================================================================
   Guaranties that Person with $id will be the only one to have a role $func-ref
   by deleting the same Role from any other Person's UserProfile
   DEPRECATED: constraint actually not in use
   ======================================================================
:)
declare function local:enforce-uniqueness ( $id as xs:string, $func-ref as xs:string , $serv-ref as xs:string?, $ca-ref as xs:string?) {
  for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef[. = $func-ref]][Id ne $id]
  let $role := $p/UserProfile/Roles/Role[FunctionRef = $func-ref]
  where ($serv-ref and ($role/ServiceRef = $serv-ref)) or ($ca-ref and ($role/RegionalEntityRef = $ca-ref) )
  return
    update delete $role
};

(: ======================================================================
   Stores a User Profile model into database for a remote user
   ======================================================================
:)
declare function local:init-remote-profile( $data as element()) as element()*{
  let $rm := fn:doc($globals:remotes-uri)/Remotes
  let $remote :=
    <Remote>
      <Name>{ $data/Contacts/Name/text() }</Name>
      <Mail>{ $data/Contacts/Mail/text() }</Mail>
      <Key>{ $data/Contacts/Key/text() }</Key>
      <Realm>{ $data/Contacts/Realm/text() }</Realm>
      <UserProfile>{ $data/Roles }</UserProfile>
    </Remote>
  return
   if (account:confirm-added-remote-login($remote, $data)) then
     (
     update insert $remote into $rm,
     let $results := local:make-ajax-response('remote-create', $remote/UserProfile/Roles, $remote/Key, $remote/Key, $remote/Realm, $remote/Name, $remote/Mail)
     let $name := local:gen-remote-name-for-display($remote)
     return 
       ajax:report-success('REMOTE-PROFILE-CREATED', ($name, $remote/Mail), $results)
     )
   else
     ajax:throw-error('SEND-CONFIRM-FAILURE', $remote/Mail)
};

(: ======================================================================
   Sends confirmation e-mail if Remote e-mail has been changed
   ====================================================================== 
:)
declare function local:confirm-added-remote-login( $remote as element(), $new as element() ) as xs:boolean* {
  let $mail := $new/Contacts/Mail
  return
    if (($mail ne '') and ($remote/Mail ne $mail)) then
      (account:confirm-added-remote-login($remote, $new), true())
    else
      (true(), false())
};

(: ======================================================================
   Updates a profile model (either a Person or a Remote) in database
   Updates a Person when $local is true, a Remote otherwise
   ======================================================================
:)
declare function local:update-profile( $model as element(), $data as element(), $local as xs:boolean ) as element()* {
  let $profile := $model/UserProfile
  let $done := 
    if ($profile) then (: update :)
      (
      (: 1. updates or deletes Roles :)
      if ($data/Roles) then
        if ($profile/Roles) then
          update replace $profile/Roles with $data/Roles
        else
          update insert $data/Roles into $profile
      else
        if ($profile/Roles) then update delete $profile/Roles else ()
      )
    else (: creation  :)
      let $profile :=  
        <UserProfile>
        {
        $data/Roles
        }
        </UserProfile>
      return
        update insert $profile into $model
  return
    (
    (: transfers submitted @ProjectId onto Person @PersonId for projet officers :)
    if ($data//FunctionRef[. eq '12']/../ProjectId) then
      (
      if ($model/@PersonId) then
        update value $model/@PersonId with $data//FunctionRef[. eq '12']/../ProjectId/text()
      else
        update insert attribute PersonId { $data//FunctionRef[. eq '12']/../ProjectId/text() } into $model,
      update delete $profile//ProjectId
      )
    else (: FIXME: maybe we should remove @PersonId from profile if role has been withdrawn :)
      (),
    (: place to implement uniqueness constaints with local:enforce-uniqueness :)
    (: e.g. 1 EASME Head of Service per Service ? :)
    if ($local) then (: DEPRECATED: eXist-DB groups not used any more :)
      local:synch-user-groups($model)
    else
      let $confirm := local:confirm-added-remote-login($model, $data)
      return
        if ($confirm[1]) then
          (
          let $results := local:make-ajax-response('remote', $model/UserProfile/Roles, $data/Contacts/Key, $model/Key, $data/Contacts/Realm, $data/Contacts/Name, $data/Contacts/Mail)
          let $name := local:gen-remote-name-for-display($model)
          return
            if ($confirm[2]) then
              ajax:report-success('REMOTE-PROFILE-UPDATED', ($name, $data/Contacts/Mail), $results)
            else
              ajax:report-success('PROFILE-UPDATED', $name, $results),
          update value $model/Name with $data/Contacts/Name/text(),
          update value $model/Mail with $data/Contacts/Mail/text(),
          update value $model/Key with $data/Contacts/Key/text(),
          update value $profile/Realm with $data/Contacts/Realm/text()
          )
       else
         ajax:throw-error('SEND-CONFIRM-FAILURE', $data/Contacts/Mail)
    )
};

declare function local:gen-roles-for-editing( $model as element()? ) {
  if (exists($model/UserProfile/Roles/Role)) then
    <Roles>
    {
      for $r in $model/UserProfile/Roles/Role
      return
        if ($r/FunctionRef/text() eq '12') then
          <Role>{ $r/*, <ProjectId>{ string($model/@PersonId) }</ProjectId> }</Role>
        else
          $r
    }
    </Roles>
  else (: safeguard to avoid AXEL infinite loop in xt:repeat on <Roles/> :)
    ()
};

(: ======================================================================
   Asserts submitted profile data and updates model in database
   ====================================================================== 
:)
declare function local:update-profile( $model as element(), $local as xs:boolean ) {
  let $data := oppidum:get-data()
  let $errors := if ($local) then 
                   local:validate-profile-submission($data, $model/Id)
                 else
                   local:validate-remote-submission($data, $model)
  return
    if (empty($errors)) then
      if ($model) then
        local:update-profile($model, $data, $local)
      else
        ajax:throw-error('URI-NOT-SUPPORTED', ())
    else
      $errors
};

(: ======================================================================
   Implements POST profiles to pre-register a profile from user management
   ====================================================================== 
:)
declare function local:POST-create-profile( $cmd as element() ) {
  let $data := oppidum:get-data()
  let $errors := local:validate-remote-submission($data, ())
  return
    if (empty($errors)) then
      local:init-remote-profile($data)
    else
      $errors
};

(: ======================================================================
   Implements POST profiles?key={key} to update a pre-registered profile
   ====================================================================== 
:)
declare function local:POST-update-profile-by-key( $cmd as element() ) {
  let $key := request:get-parameter('key', ())
  let $model := fn:doc($globals:remotes-uri)//Remote[Key = $key]
  return
    local:update-profile($model, false())
};

(: ======================================================================
   Implements POST profiles/{id} to update a permanent profile
   ====================================================================== 
:)
declare function local:POST-update-profile-by-id( $cmd as element() ) {
  let $id := string($cmd/resource/@name)
  let $model := fn:collection(oppidum:path-to-ref-col())//Person[Id = $id]  
  return
    local:update-profile($model, true())
};

(: ======================================================================
   Implements POST profiles?key={key} to edit pre-registered profile
   ====================================================================== 
:)
declare function local:GET-read-profile-by-key-for-editing( $cmd as element() ) {
  let $key := request:get-parameter('key', ())
  let $model := fn:doc($globals:remotes-uri)//Remote[Key = $key]
  return
    <UserProfile>
      <Contacts>
        { $model/Name }
        { $model/Mail }
        <Key>{ $key }</Key>
        { $model/Realm }
      </Contacts>
      { local:gen-roles-for-editing($model) }
    </UserProfile>
};

(: ======================================================================
   Implements GET profiles/{id} to edit a permanent profile
   ====================================================================== 
:)
declare function local:GET-read-profile-by-id-for-editing( $cmd as element() ) {
  let $id := string($cmd/resource/@name)
  let $model := fn:collection(oppidum:path-to-ref-col())//Person[Id = $id]  
  return
    <UserProfile>
      { local:gen-roles-for-editing($model) }
    </UserProfile>
};

(: MAIN ENTRY POINT - CONTROLLER ROUTING :)
let $cmd := oppidum:get-command()
let $m := request:get-method()
let $target := string($cmd/resource/@name)
return
  (: FIXME: add access control :)
  if ($m eq 'POST') then
    if ($cmd/@action eq 'add') then (: POST profiles/add :)
      local:POST-create-profile($cmd)
    else if ($target eq 'profiles') then (: POST profiles?key={key} :)
      local:POST-update-profile-by-key($cmd)
    else (: POST profiles/{id} :)
      local:POST-update-profile-by-id($cmd)
  else
    if ($target eq 'profiles') then (: GET profiles?key={key} :)
      local:GET-read-profile-by-key-for-editing($cmd)
    else (: GET profiles/{id} :)
      local:GET-read-profile-by-id-for-editing($cmd)
