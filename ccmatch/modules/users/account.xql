xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage users access login :
   - GET, POST to change login
   - POST to "/delete" to delete (see 'ow-delete' command)
   - POST to "?regenerate=1" to generate a new password (see 'ow-password' command)
   - returns Oppidum JSON response protocol except for GET

   PRE-REQUISITE:
   - configure Sudoer in settings

   SEE ALSO: 
   - formulars/account.xml formular
   - password.xql (forgotten password tunnel for end users)
  
   TODO:
   - use DELETE instead of POST to "/delete"

   October 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace system = "http://exist-db.org/xquery/system";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://oppidoc.com/ns/account" at "account.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

(:declare option exist:serialize "method=xml media-type=text/xml";:)
declare option exist:serialize "method=json media-type=application/json";

declare function local:render-message-for( $p as element(), $type as xs:string, $clues as xs:string* ) as element() {
  let $what := if ($p/Information/Uuid) then concat($type, '-PUBLIC') else $type
  return 
    <Suggestion>{ string(oppidum:render-message('/db/www/ccmatch', $what, $clues, 'en', false())) }</Suggestion>
};

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
      if (xdb:exists-user($login)) then (: includes case when changing login to same login :)
        ajax:throw-error('ACCOUNT-DUPLICATED-LOGIN', $login)
      else
        (),
      if ($login = distinct-values(fn:doc('/db/www/ccmatch/config/mapping.xml')/site/item/@name)) then
        ajax:throw-error('ACCOUNT-FORBIDDEN-LOGIN', $login)
      else
        ()
        (: FIXME: vérifier aussi que le Username est pas déjà pris par un Person sans login ? :)
      )
};

(: ======================================================================
   Updates a Username and generates a new password to access the application
   ======================================================================
:)
declare function local:update-user-account( $person as element(), $data as element(), $lang as xs:string ) as element() {
  let $old-login := normalize-space(string($person/UserProfile/Username))
  let $new-login := normalize-space($data/Login)
  let $new-pwd := account:gen-password($old-login, $person/Information/Contacts/Email)
  let $groups := if (xdb:exists-user($old-login)) then (: handles very specific case of Username w/o eXist-DB login :)
                   xdb:get-user-groups($old-login) (: saves current group membership :)
                 else 
                   account:gen-groups-for-user($person)
  let $to := normalize-space($person/Information/Contacts/Email)
  return (
    system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:create-user($new-login, $new-pwd, $groups, ())),
    if (xdb:exists-user($new-login)) then (: check operation was successful :)
      (
      update value $person/UserProfile/Username with $new-login,
      (: TODO: add a test case to prevent admin system to delete herself ? :)
      if (($old-login ne $new-login) and xdb:exists-user($old-login)) then (: sanity check :)
        system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:delete-user($old-login))
      else
        (),
      if (account:send-updated-login($person, $new-login, $new-pwd, $to)) then
        let $result := person:gen-update-sample-for-mgt-table($person)
        return
          ajax:report-success('ACCOUNT-LOGIN-UPDATED', concat($to, " (login : ", $new-login, "; password : ", $new-pwd, "; groups : ", string-join($groups,"'"), ")"), $result)
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
  let $new-pwd := account:gen-password($new-login, $person/Information/Contacts/Email)
  let $groups := account:gen-groups-for-user($person)
  let $to := normalize-space($person/Information/Contacts/Email)
  let $cmd := oppidum:get-command()
  return (
    system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:create-user($new-login, $new-pwd, $groups, ())),
    if (xdb:exists-user($new-login)) then (: check operation was successful :)
      (
      if ($person/UserProfile) then
        update insert <Username>{$new-login}</Username> into $person/UserProfile
      else
        update insert <UserProfile><Username>{$new-login}</Username></UserProfile> into $person,
      if (account:send-created-login($person, $new-login, $new-pwd, $to)) then
        let $result := person:gen-update-sample-for-mgt-table($person)
        return
          if ($person//Uuid) then (
            (: coming from registration page, must be redirected to login page :)
            update insert <RegistrationUuid>{$person//Uuid/text()}</RegistrationUuid> following $person/Id,
            update delete $person/Information/Uuid,
            ajax:report-success-redirect('ACCOUNT-LOGIN-CREATED', concat($to, " (login : ", $new-login, ")"), concat($cmd/@base-url, 'login'))
            )
          else
            ajax:report-success('ACCOUNT-LOGIN-CREATED', concat($to, " (login : ", $new-login, "; password : ", $new-pwd, "; groups : ", string-join($groups,","), ")"), $result)
      else
        ajax:throw-error('SEND-PASSWORD-FAILURE', $to)
      )
    else
      ajax:throw-error('ACCOUNT-CREATE-LOGIN-FAILED', $new-login)
    )
};

(: ======================================================================
   Switch function to create or update an user account
   Pre-condition: correct e-mail address in database
   (Username and database access password)
   ======================================================================
:)
declare function local:create-or-update-account( $person as element(), $lang as xs:string ) as element() {
  let $to := normalize-space($person/Information/Contacts/Email)
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
   TODO: check login available and add number if not (!)
   ====================================================================== 
:)
declare function local:gen-new-login( $p as element() ) as xs:string {
  let $name := $p/Information/Name
  let $core1 := $name/LastName
  let $core2 := replace(replace(replace($core1, "^de la ","dela"), "^de ", "de"), "^van der ", "vander")
  let $core3 := if (contains($core2, " ")) then substring-before($core2, " ") else $core2
  let $use := translate($core3, "áàéèíôóçćü","aaeeiooccu") (: normalize-unicode(x,"NFKD") not working :)
  return
    concat(translate(
             lower-case(substring(normalize-space($name/FirstName), 1, 1)), 
             "áàéèíôóçü","aaeeioocu"), 
           '-', lower-case($use))
};

(: ======================================================================
   Suggestion service to create a new login in coordination with Case Tracker
   Filters request object and add coach login suggestion by contacting case tracker
   ====================================================================== 
:)
declare function local:suggest-login-for( $p as element() ) as element()* {
  if (request:get-parameter('goal', ()) eq 'create') then
    let $email := $p/Information/Contacts/Email
    return
      if ($email) then 
        let $payload := <Export>{$email}</Export>
        let $coaches := services:post-to-service('cctracker', 'cctracker.coaches', $payload, "200")
        return
          if (local-name($coaches) ne 'error') then
            if (count($coaches//Coach) > 1) then
              local:render-message-for($p, 'LOGIN-TOO-MUCH-MATCH', $email)
            else if (count($coaches//Coach) = 1) then
              let $remote := $coaches//Coach
              let $name := concat($remote/Name/LastName, ' ', $remote/Name/FirstName)
              return
                if ($remote/Username) then
                  let $taken := fn:collection($globals:persons-uri)//Person[UserProfile/Username eq $remote/Username/text()]
                  return
                    if ($taken) then
                      local:render-message-for($p, 'LOGIN-TAKEN-CASE-TRACKER', ($name, $email, $remote/Username/text(), display:gen-person-name($p, 'en'), display:gen-person-name($taken, 'en'), $taken/Information/Contacts/Email))
                    else
                      (
                      <Login>{ $remote/Username/text() }</Login>,
                      local:render-message-for($p, 'LOGIN-FOUND-CASE-TRACKER', ($name, $email, display:gen-person-name($p, 'en')))
                      )
                else (
                  <Login>{ local:gen-new-login($p) }</Login>,
                  local:render-message-for($p, 'LOGIN-FOUND-NOLOGIN-CASE-TRACKER', ($name, $email))
                )
            else (
              <Login>{ local:gen-new-login($p) }</Login>,
              local:render-message-for($p, 'LOGIN-SUGGEST-FIRST', (display:gen-person-name($p, 'en'), $email))
              )
          else
            let $msg := $coaches/message/text()
            return
              (
              (: FIXME: we need to override service raised error so that AXEL can load the answer
                        maybe service should set response status code ? :)
              response:set-status-code(200),
              <Login>{ local:gen-new-login($p) }</Login>,
              local:render-message-for($p, 'LOGIN-CASE-TRACKER-FAILED', $coaches/message/text())
              )
      else
        <Suggestion>could not suggest a login because the email address is missing</Suggestion>
  else
    ()
};

(: ======================================================================
   FIXME: admin-system checkbox ?
   ======================================================================
:)
declare function local:gen-user-account-for-editing( $p as element()? ) as element()* {
  let $output := util:declare-option("exist:serialize", "method=xml media-type=text/xml")  
  return
    if (empty($p) or empty($p/UserProfile) or empty($p/UserProfile/Username)) then
      <Account>
        { 
        $p/Information/Contacts/Email,
        local:suggest-login-for($p)
        }
        <Access>no</Access>
      </Account>
    else
      <Account>
        {
        let $u := $p/UserProfile/Username
        return (
          $p/Information/Contacts/Email,
          $u,
          if ($u/text() and xdb:exists-user($u/text())) then
            <Access>yes</Access>
          else
            <Access>no</Access>
          )
        }
      </Account>
};

(: ======================================================================
   Removes user access from the database by removing his login and his Username
   ======================================================================
:)
declare function local:delete-account( $person as element() ) {
  let $uname := string($person/UserProfile/Username)
  return
    if ($uname) then
      if (normalize-space($uname) eq xdb:get-current-user()) then
        ajax:throw-error('PROTECT-ADMIN-SYSTEM-LOGIN', ())
      else
        (
        if (xdb:exists-user(normalize-space($uname))) then
          system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:delete-user(normalize-space($uname)))
        else
          (),
        update delete $person/UserProfile/Username,
        let $result := person:gen-update-sample-for-mgt-table($person)
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
  let $to := normalize-space($user/Information/Contacts/Email/text())
  let $new-pwd := account:gen-password($user/UserProfile/Username, $to)
  let $output := util:declare-option("exist:serialize", "method=xml media-type=text/xml")
  return
    if ($user/UserProfile/Username and xdb:exists-user(normalize-space($user/UserProfile/Username))) then (
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
let $lang := string($cmd/@lang)
let $person-ref := string($cmd/resource/@name)
let $person := fn:collection($globals:persons-uri)//Person[Id eq $person-ref or Information/Uuid/text() eq $person-ref]
return
  if ($m = 'POST') then
    if ($person/Information/Uuid or access:user-belongs-to('admin-system')) then
      if (string($cmd/@action) = 'delete') then 
        (: assumes client-side confirmation already done with data-confirm :)
        local:delete-account($person)
      else if (request:get-parameter('regenerate', ()) = '1') then
        local:regenerate-pwd($person)
      else
        if ($person/Information/Uuid) then
          system:as-user(account:get-secret-user(), account:get-secret-password(), local:create-or-update-account($person, $lang))
        else
          local:create-or-update-account($person, $lang)
    else
      if (empty($person)) then
        ajax:throw-error('URI-NOT-FOUND', ())
      else
        oppidum:throw-error('FORBIDDEN', ())
  else (: assumes GET :)
    if ($person/Information/Uuid or access:user-belongs-to('admin-system')) then
      local:gen-user-account-for-editing($person)
    else
      if (empty($person)) then
        ajax:throw-error('URI-NOT-FOUND', ())
      else
        oppidum:throw-error('FORBIDDEN', ())
        
