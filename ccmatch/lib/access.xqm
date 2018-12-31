xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC XQuery Content Management Framework

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Access control engine implemented as XQuery functions

   To be use to control :
   - display of command buttons in the user interface
   - fine grain access to CRUD controllers

   Conventions:
   - access:assert-* : low-level functions implementing access control mini-language (see application.xml)
   - assert:check-* : high-level boolean functions to perform a check

   Do not forget to also set mapping level <access> rules to prevent URL forgery !

   January 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace access = "http://oppidoc.com/oppidum/access";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace nonce = "http://oppidoc.com/oppidum/nonce" at "nonce.xqm";

(: ======================================================================
   @return The Person element for the current user
   ======================================================================
:)
declare function access:get-current-person () as element()? {
  let $user := oppidum:get-current-user()
  let $realm := oppidum:get-current-user-realm()
  return
    if (empty($realm) or ($realm eq 'EXIST')) then
      fn:collection($globals:persons-uri)//Person[UserProfile/Username eq $user]
    else
      fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq $realm] eq $user]
};

(: ======================================================================
   Returns the Id of the current user or () if the current user
   is not associated with a person in the databse.
   ======================================================================
:)
declare function access:get-current-person-id () as xs:string? {
  access:get-current-person-id (oppidum:get-current-user())
};

declare function access:get-current-person-profile() as element()? {
  let $realm := oppidum:get-current-user-realm()
  let $user := oppidum:get-current-user()
  return
    if (empty($realm) or ($realm eq 'EXIST')) then
      fn:collection($globals:persons-uri)//Person/UserProfile[Username eq $user]
    else
      fn:collection($globals:persons-uri)//Person/UserProfile[Remote[@Name eq $realm] eq $user]
};

(: ======================================================================
   Variant of the above function when the current user is known
   ======================================================================
:)
declare function access:get-current-person-id ( $user as xs:string ) as xs:string? {
  let $realm := oppidum:get-current-user-realm()
  return
    if (empty($realm) or ($realm eq 'EXIST')) then
      fn:collection($globals:persons-uri)//Person[UserProfile/Username eq $user]/Id/text()
    else
      fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq $realm] eq $user]/Id/text()
};

(: ======================================================================
   Returns the function reference corresponding to a role identified by its name
   Returns the empty sequence in case role unknown or empty input
   This is mainly to ease up code maintenance
   ======================================================================
:)
declare function access:get-function-ref-for-role( $roles as xs:string* ) as xs:string*  {
  if (exists($roles)) then
    fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role = $roles]/Id/text()
  else
    ()
};

(: ======================================================================
   Returns true() if current user belongs to database group
   ====================================================================== 
:)
declare function access:user-belongs-to( $role as xs:string) as xs:boolean {
  let $groups := oppidum:get-current-user-groups()
  return
    ($role = $groups)
};

(: ======================================================================
   Returns true if user holds a given application role
   ====================================================================== 
:)
declare function access:has-role( $person as element(), $role as xs:string ) as xs:boolean {
  let $function := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role = $role]/Id
  return
    exists($person//Role[FunctionRef eq $function])
};

(: ======================================================================
   Returns an empty list of host refs if user is host manager
   ====================================================================== 
:)
declare function access:get-managed-hosts( $person as element()) as xs:string* {
  let $function := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role = 'host-manager']/Id
  return
    let $role := $person//Role[FunctionRef eq $function]
    return $role/HostRef/text()
};

(: ======================================================================
   Implements fine grain access rules :
   - Integer tokens can be used by system administrators to see users dashboards,
     to manage users, or from within suggestion tunnel (check with Referer's header)
   - other tokens are supposed to identify users by their username URL mapping

   @param $token An Integer token representing a user database identifier or
   a String token representing the mapping associated to a username in the current realm
   @return The person element corresponding to token or an Oppidum error
   @deprecated To be replaced with access:get-person-from-host
   ====================================================================== 
:)
declare function access:get-person( $token as xs:string, $user as xs:string, $groups as xs:string*) as element() {
  if (matches($token, '^\d+$')) then (: an admin inspecting or a KAM from a suggestion tunnel :)
    let $referer := request:get-header('Referer')
    return
      if (('admin-system' = $groups) or (ends-with($referer, '/suggest'))) then
        let $person := fn:collection($globals:persons-uri)//Person[Id eq $token]
        return 
          if ($person) then $person else oppidum:throw-error('NOT-FOUND', ())
      else
        oppidum:throw-error('FORBIDDEN', ())
  else (: a user viewing himself or an admin inspecting persons :)
    let $username := access:username-from-mapping($token)
    let $realm := oppidum:get-current-user-realm()
    return
      let $person := 
        if (empty($realm) or ($realm eq 'EXIST')) then
          fn:collection($globals:persons-uri)//Person[UserProfile/Username eq $username]
        else
          fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq $realm] eq $username]
      return
        if ($person) then
          let $viewer-id := access:get-current-person-id($user)
          return
            if (($viewer-id eq $person/Id) or ('admin-system' = $groups)) then
              $person 
            else
              oppidum:throw-error('FORBIDDEN', ())
        else 
          oppidum:throw-error('NOT-FOUND', ())
};

(: ======================================================================
   Checks authorization token to grant acces to guest otherwise fallback
   to access:get-person
   Pre-condition: only compatible with integer user's token !
   ====================================================================== 
:)
declare function access:get-person-nonce( $token as xs:string, $user as xs:string, $groups as xs:string* ) as element() {
  let $auth := request:get-parameter('auth', ())
  return
    if ($auth) then
      let $nonce := nonce:validate($auth)
      return
        if (local-name($nonce) ne 'error') then
          let $person := fn:collection($globals:persons-uri)//Person[Id eq $token]
          return 
            if ($person) then $person else oppidum:throw-error('NOT-FOUND', ())
        else
          $nonce
    else
      access:get-person($token, $user, $groups)
};

(: ======================================================================
   Returns the person model if she has set her preferences to be visible from host 
   or an Oppidum error. Always return the person model if called by an admin system 
   or the user himself
   ====================================================================== 
:)
declare function access:get-person-from-host( $token as xs:string, $user as xs:string, $groups as xs:string*, $host-ref as xs:string ) {
  let $person :=
    if (matches($token, '^\d+$')) then
      fn:collection($globals:persons-uri)//Person[Id eq $token]
    else (: a user viewing himself or an admin inspecting persons, implies $host-ref is 0 :)
      let $username := access:username-from-mapping($token)
      let $realm := oppidum:get-current-user-realm()
      return
        if (empty($realm) or ($realm eq 'EXIST')) then
          fn:collection($globals:persons-uri)//Person[UserProfile/Username eq $username]
        else
          fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq $realm] eq $username]
  return
    if ($person) then
      let $viewer-id := access:get-current-person-id($user)
      return
        if ( ('admin-system' = $groups)
             or ($viewer-id eq $person/Id)
             or ($person/Preferences/Visibility[@For eq $host-ref]/YesNoAcceptRef eq '1') ) then
             (: FIXME: check Preferences/Coaching if $host-ref ne '0' ? :)
          $person
        else
          oppidum:throw-error('FORBIDDEN', ())
    else
      oppidum:throw-error('NOT-FOUND', ())
};

(: ======================================================================
   Returns true() if the user with the given groups can edit the person's profile
   TODO: real Host by host magement
   ====================================================================== 
:)
declare function access:can-edit-profile( $person as element(), $user as xs:string?, $groups as xs:string* ) as xs:boolean {
  ($person/Id eq access:get-current-person-id($user)) or ($groups = 'admin-system')
};

(: ======================================================================
   Encodes a username into a URL compatible token to generate the user's 
   home page URL. You may need this if you use non compatible usernames 
   such as an e-mail addresses (not the case).

   @param $name The username (as per oppidum:get-current-user) in the current realm
   ======================================================================
:)
declare function access:mapping-from-username( $name as xs:string ) as xs:string {
  $name
};

(: ======================================================================
   Decodes a user's URL token into a username token. This is the inverse 
   of access:mapping-from
   Pre-condition : mapping MUST be an encoded username (and not a user 
   database identifier)
   ======================================================================
:)
declare function access:username-from-mapping( $mapping as xs:string ) as xs:string {
  $mapping
};

(: ======================================================================
   Implements Allow access control rules
   Limitations: only interprets comma separated list of g:token
   See stats.xml @Allow or @ExcelAllow on Command element
   TODO: implement s:omni for users with sight omni
   ======================================================================
:)
declare function access:check-rule( $rule as xs:string? ) as xs:boolean {
  if (empty($rule) or ($rule eq '')) then
    true()
  else
    let $groups := oppidum:get-current-user-groups()
    let $allowed := tokenize($rule,"\s*g:")[. ne '']
    return 
      $groups = $allowed
};

(: ======================================================================
   Rule to display command buttons in Statistics, give access to the underlying 
   functionality and display "Export excel csv" link in tables in export or print lists.
   Returns true() if allowed, false() otherwise.
   TODO: replace with check-user-can
   ======================================================================
:)
declare function access:check-stats-action( $page as xs:string, $action as xs:string, $link as xs:boolean ) as xs:boolean {
  let $command := fn:doc(oppidum:path-to-config('stats.xml'))/Statistics/Filters/Filter[@Page = $page]/Formular/Command[@Action eq $action]
  return 
    if ($link) then
      access:check-rule(string($command/@ExcelAllow))
    else
      access:check-rule(string($command/@Allow))
};

(: ======================================================================
   Generic access control function
   TODO: 
   - add target host parameter
   - test host manager role
   ====================================================================== 
:)
declare function access:check-user-can( $action as xs:string, $entity as xs:string ) as xs:boolean {
  if (oppidum:get-current-user-groups() = 'admin-system') then
    true()
  else
    if (($action eq 'search') and ($entity eq 'Coach')) then 
      (: user must be have been accepted at some host :)
      let $profile := access:get-current-person()
      return
        exists($profile/Hosts/Host[AccreditationRef eq '4'])
        
    else
      false()
};

