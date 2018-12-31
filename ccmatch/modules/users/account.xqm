xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utility functions to manage user's accounts

   April 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace account = "http://oppidoc.com/ns/account"; 

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../../lib/media.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare variable $account:settings-uri := '/db/www/cctracker/config/settings.xml';

(: ======================================================================
   Returns secret user to call system:as-user
   ====================================================================== 
:)
declare function account:get-secret-user() as xs:string {
  if (exists(fn:doc($globals:settings-uri)/Settings/Sudoer/User)) then 
    fn:doc($globals:settings-uri)/Settings/Sudoer/User
  else 
    let $err := oppidum:throw-error('INCOMPLETE-APP-CONFIG', ())
    return 'guest'
};

(: ======================================================================
   Returns secret user password to call system:as-user
   ====================================================================== 
:)
declare function account:get-secret-password() as xs:string? {
  fn:doc($globals:settings-uri)/Settings/Sudoer/Password
};

(: ======================================================================
   Utility to return variables representing current user name
   ======================================================================
:)
declare function local:gen-user-name( $prefix as xs:string, $ref as xs:string? ) as element()* {
  let $person := fn:collection($globals:persons-uri)//Person[Id = $ref]
  return
    if ($person) then (
      <var name="{$prefix}_First_Name">{ $person/Information/Name/FirstName/text() }</var>,
      <var name="{$prefix}_Last_Name">{ $person/Information/Name/LastName/text() }</var>
      )
    else
      <var name="{$prefix}_First_Name">UNKNOWN ref({ $ref }) {$prefix}</var>
};

(: ======================================================================
   Returns the list of eXist groups that the $person user should belong to 
   NOTE: uses GlobalInformation 'en' section !
   ======================================================================
:)
declare function account:gen-groups-for-user( $person as element() ) as xs:string* {
  (
  "users",
  for $ref in $person/UserProfile/Roles/Role/FunctionRef/text()
  let $f := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[Id = $ref]
  return $f/@Group
  )
};

(: ======================================================================
   Function to generate a random password
   ======================================================================
:)
declare function account:gen-password ( $name as xs:string, $email as xs:string ) {
  let $boot := concat($name, current-dateTime(), $email)
  let $next := util:hash($boot,"md5")
  let $seed := 
        string-join(
    for $i in 1 to string-length($next)
    return
        if (($i mod 2 = 0) or ($i mod 3 = 0) or ($i mod 5 = 0)) then
          translate(substring($next, $i, 1),"012345", "aeiouy")
        else
          substring($next, $i, 1),
        ''
        )
  let $max := string-length($seed)
  return
    string-join(
      for $i in 1 to 8 
      return 
           let $pos := util:random($max)
           let $res := substring($seed, $pos, 1)
           return 
               if ($pos > $max div 2) then
                    upper-case($res)
               else
                    $res,
      '')
};

(: ======================================================================
   Sends an email message to inform a user of his/her new generated password
   on behalf of the user himself or of an application administrator
   ======================================================================
:)
declare function account:send-new-password( $user as element(), $pwd as xs:string, $to as xs:string, $askedByUser as xs:boolean ) as xs:boolean {
  let $template := if ($askedByUser) then 'new-password-by-user' else 'new-password-by-admin'
  let $from := if ($askedByUser) then () else media:gen-current-user-email(false())
  let $email :=
    media:render-email($template,
      <vars>
        <var name="Password">{ $pwd }</var>
        { local:gen-user-name('Admin', access:get-current-person-id()) }
        { local:gen-user-name('User', $user/Id/text()) }
      </vars>,
      'en'
      )
  return
    media:send-email('account', $from, $to, $email/Subject/text(), media:message-to-plain-text($email/Message))
};

(: ======================================================================
   Sends an email message to inform a user of his new account information to access the application
   on behalf of an application administrator
   ======================================================================
:)
declare function account:send-created-login( $user as element(), $login as xs:string, $pwd as xs:string, $to as xs:string) as xs:boolean {
  let $from := media:gen-current-user-email(false())
  let $cat := if ($user//Uuid) then 'registration' else 'account' 
  let $email :=
    media:render-email(if ($user//Uuid) then 'login-self-created' else 'login-created',
      <vars>
        <var name="Login">{ $login }</var>
        <var name="Password">{ $pwd }</var>
        { local:gen-user-name('Admin', access:get-current-person-id()) }
        { local:gen-user-name('User', $user/Id/text()) }
      </vars>,
      'en'
      )
  return
    media:send-email($cat, $from, $to, $email/Subject/text(), media:message-to-plain-text($email/Message))
};

(: ======================================================================
   Sends an email message to inform a user of his updated account information to access the application
   on behalf of an application administrator
   ======================================================================
:)
declare function account:send-updated-login( $user as element(), $login as xs:string, $pwd as xs:string, $to as xs:string ) as xs:boolean {
  let $from := media:gen-current-user-email(false())
  let $email :=
    media:render-email('login-updated',
      <vars>
        <var name="Login">{ $login }</var>
        <var name="Password">{ $pwd }</var>
        { local:gen-user-name('Admin', access:get-current-person-id()) }
        { local:gen-user-name('User', $user/Id/text()) }
      </vars>,
      'en'
      )
  return
    media:send-email('account', $from, $to, $email/Subject/text(), media:message-to-plain-text($email/Message))
};
