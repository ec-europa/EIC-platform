xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage Username of users inside the database
   and to change eXist-DB user accordingly

   WARNING: this script calls as-user with the "prometheus" account which must be granted DBA role
   
   TODO:
   - use a real delete HTTP verb (but we had some limitations when running under Tomcat)

   April 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace system = "http://exist-db.org/xquery/system";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "account.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Checks submitted account data is valid
   ======================================================================
:)
declare function local:validate-user-account-submission( $data as item()? ) as element()* {
  if (not($data instance of element())) then
    ajax:throw-error('VALIDATION-FORMAT-ERROR', ())
  else
    let $login := normalize-space($data/Login)
    return (
        if (matches($login, "^\s*[\w\-]{4,}\s*$")) then
          ()
        else
          ajax:throw-error('ACCOUNT-MALFORMED-LOGIN', $login),
        if (sm:user-exists($login)) then (: includes case when changing login to same login :)
          ajax:throw-error('ACCOUNT-DUPLICATED-LOGIN', $login)
        else
          ()
          (: FIXME: vérifier aussi que le Username est pas déjà pris par un Person sans login ? :)
        )
};

declare function local:make-ajax-response( $key as xs:string, $login as xs:string, $id as xs:string ) {
  <Response Status="success">
    <Payload Key="{$key}">
      <Name>{ $login }</Name>
      <Value>{ $id }</Value>
    </Payload>
  </Response>
};

(: ======================================================================
   Updates a Username and generates a new password to access the application
   ======================================================================
:)
declare function local:update-user-account( $person as element(), $data as element(), $lang as xs:string ) as element() {
  let $old-login := normalize-space(string($person/UserProfile/Username))
  let $new-login := normalize-space($data/Login)
  let $new-pwd := account:gen-password($old-login, $person/Contacts/Email)
  let $groups := if (sm:user-exists($old-login)) then (: handles very specific case of Username w/o eXist-DB login :)
                   xdb:get-user-groups($old-login) (: saves current group membership :)
                 else 
                   account:gen-groups-for-user($person)
  let $to := normalize-space($person/Contacts/Email)
  return (
    system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:create-user($new-login, $new-pwd, $groups, ())),
    if (sm:user-exists($new-login)) then (: check operation was successful :)
      (
      update value $person/UserProfile/Username with $new-login,
      (: TODO: add a test case to prevent admin system to delete herself ? :)
      if (($old-login ne $new-login) and sm:user-exists($old-login)) then (: sanity check :)
        system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:delete-user($old-login))
      else
        (),
      if (account:send-updated-login($person, $new-login, $new-pwd, $to)) then
        let $result :=
            if (request:get-parameter('table', '')= '') then
              local:make-ajax-response('login', $new-login, $person/Id)
            else
            (
          util:declare-option("exist:serialize", "method=json media-type=application/json"),
              person:gen-update-sample-for-mgt-table($person))
        return
          ajax:report-success('ACCOUNT-LOGIN-UPDATED', concat($to, " (login : ", $new-login, "; mot de passe généré : ", $new-pwd, "; groupes : ", string-join($groups,"'"), ")"), $result)
      else
        ajax:throw-error('SEND-PASSWORD-FAILURE', $to)
      )
    else
      ajax:throw-error('ACCOUNT-CREATE-LOGIN-FAILED', $new-login)
    )
};

(: ======================================================================
   Creates a Username and generates a new password to access the application
   Pre-condition: Person/UserProfile/Username does not exists !
   ======================================================================
:)
declare function local:create-user-account( $person as element(), $data as element(), $lang as xs:string ) as element() {
  let $new-login := normalize-space($data/Login)
  let $new-pwd := account:gen-password($new-login, $person/Contacts/Email)
  let $groups := account:gen-groups-for-user($person)
  let $to := normalize-space($person/Contacts/Email)
  return (
    system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:create-user($new-login, $new-pwd, $groups, ())),
    if (sm:user-exists($new-login)) then (: check operation was successful :)
      (
      if ($person/UserProfile) then
        update insert <Username>{$new-login}</Username> into $person/UserProfile
      else
        update insert <UserProfile><Username>{$new-login}</Username></UserProfile> into $person,
      if (account:send-created-login($person, $new-login, $new-pwd, $to)) then
        let $result :=
            if (request:get-parameter('table', '')= '') then
              local:make-ajax-response('nologin', $new-login, $person/Id)
            else
            (
          util:declare-option("exist:serialize", "method=json media-type=application/json"),
              person:gen-update-sample-for-mgt-table($person))
        return
          ajax:report-success('ACCOUNT-LOGIN-CREATED', concat($to, " (login : ", $new-login, "; mot de passe généré : ", $new-pwd, "; groupes : ", string-join($groups,","), ")"), $result)
      else
        ajax:throw-error('SEND-PASSWORD-FAILURE', $to)
      )
    else
      ajax:throw-error('ACCOUNT-CREATE-LOGIN-FAILED', $new-login)
    )
};

(: ======================================================================
   Switch function to create or update an user account
   (Username and database access password)
   ======================================================================
:)
declare function local:create-or-update-account( $person as element(), $lang as xs:string ) as element() {
  let $to := normalize-space($person/Contacts/Email) (: pre-condition: email to send new access information :)
  return
    if ($to) then
      (: FIXME: check data is really a UserProfile element and not a string :)
      let $data := oppidum:get-data()
      let $errors := local:validate-user-account-submission($data)
      return
        if (empty($errors)) then
          if ($person/UserProfile/Username) then 
            local:update-user-account($person, $data, $lang)
          else
            local:create-user-account($person, $data, $lang)
        else
          ajax:report-validation-errors($errors)
    else
      ajax:throw-error('ACCOUNT-MISSING-EMAIL', ())
};

(: ======================================================================
  FIXME: admin-system checkbox ?
   ======================================================================
:)
declare function local:gen-user-account-for-editing( $p as element()? ) as element()* {
  if (empty($p) or empty($p/UserProfile) or empty($p/UserProfile/Username)) then
    <UserProfile>
      { $p/Contacts/Email }
      <Access>non</Access>
    </UserProfile>
  else
    <UserProfile>
      {
      let $u := $p/UserProfile/Username
      return (
        $p/Contacts/Email,
        $u,
        if ($u/text() and sm:user-exists($u/text())) then
          <Access>yes</Access>
        else
          <Access>no</Access>
        )
      }
    </UserProfile>
};

(: ======================================================================
   Removes user access from the database by removing his login and his Username
   ======================================================================
:)
declare function local:delete-account( $person as element() ) {
  let $uname := string($person/UserProfile/Username)
  let $cur := access:get-current-person-profile()
  return
    if ($uname) then
      if (normalize-space($uname) eq normalize-space($cur/Username)) then
        ajax:throw-error('PROTECT-ADMIN-SYSTEM-LOGIN', ())
      else
        (
        if (sm:user-exists(normalize-space($uname))) then
          system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:delete-user(normalize-space($uname)))
        else
          (),
        update delete $person/UserProfile/Username,
        let $result :=
            if (request:get-parameter('table', '')= '') then
              local:make-ajax-response('login', $uname, $person/Id)
            else
            (
          util:declare-option("exist:serialize", "method=json media-type=application/json"),
              person:gen-update-sample-for-mgt-table($person))
        return
          ajax:report-success('ACCOUNT-LOGIN-DELETED', $uname, $result)
        )
    else
      ajax:throw-error('URI-NOT-SUPPORTED', ())
};

(: ======================================================================
   Generates a new password and send it to the user
   See also gen-new-password in password.xql
   ======================================================================
:)
declare function local:regenerate-pwd( $user as element() ) {
  let $to := normalize-space($user/Contacts/Email/text())
  let $new-pwd := account:gen-password($user/UserProfile/Username, $to)
  return
    if ($user/UserProfile/Username and sm:user-exists(normalize-space($user/UserProfile/Username))) then (
      system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:change-user($user/UserProfile/Username, $new-pwd, (), ())),
      if (account:send-new-password($user, $new-pwd, $to, false())) then
        ajax:report-success('ACCOUNT-PWD-CHANGED-MAIL', concat($to, " (new password : ", $new-pwd, ")"))
      else
        ajax:report-success('ACCOUNT-PWD-CHANGED-NOMAIL', concat($to, " (new password : ", $new-pwd, ")"))
      )
    else
      (: very marginal case when Username exists in profile but the login does not exists in database :)
      ajax:throw-error('ACCOUNT-PWD-NO-ACCOUNT', $user/UserProfile/Username/text())
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $id := string($cmd/resource/@name)
let $person := fn:collection(oppidum:path-to-ref-col())//Person[Id = $id]
let $lang := string($cmd/@lang)
return
  if ($m = 'POST') then
    if ($person) then
      if (string($cmd/@action) = 'delete' or request:get-parameter('_delete', '0') = '1') then (: we could also check _delete parameter eq 1 see 'c-delete' command in extension.js :)
        local:delete-account($person)
      else if (request:get-parameter('regenerate', ()) = '1') then
        local:regenerate-pwd($person)
      else
        local:create-or-update-account($person, $lang)
    else
      ajax:throw-error('URI-NOT-SUPPORTED', ())
  else (: assumes GET :)
    local:gen-user-account-for-editing($person)
