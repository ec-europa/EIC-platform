xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Support method for periodical accounts cleanup

   July 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace check = "http://oppidoc.com/ns/alert/check";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace account = "http://oppidoc.com/ns/account" at "../users/account.xqm";

(: ======================================================================
   Returns true() if the account is older than $local:dangling-interval
   FIXME: encode StatusHistory as dateTime and use it instead of $person/@Creation
   ====================================================================== 
:)
declare function check:can-delete( $person as element(), $threshold as xs:dayTimeDuration ) as xs:boolean {
  let $stop := current-dateTime()
  (:let $start-date := $person/StatusHistory/Status[ValueRef eq '2']/Date:)
  let $start-date := xs:dateTime(string($person/@Creation))
  return 
    (current-dateTime() - $start-date) > $threshold
    (:if ($start-date) then
      days-from-duration($stop - xs:date($start-date)) ge 1
    else
      false:)
};

(: ======================================================================
   Removes self-registered accounts where the user didn't create a login
   Note: Entry data must be cloned (string function) because otherwise 
   it wont exist when written to log after deletion (!)
   ====================================================================== 
:)
declare function check:remove-dangling-account( $threshold as xs:dayTimeDuration ) as element()* {
  for $person in fn:collection($globals:persons-uri)//Person[Information/Uuid]
  let $uname := $person/UserProfile/Username
  where check:can-delete($person, $threshold)
  return
    let $col-name := misc:gen-collection-name-for(number($person/Id))
    let $col-uri := concat($globals:persons-uri,'/', $col-name)
    let $file := concat($person/Id,'.xml')
    let $entry := 
      <Entry>
        <Type>delete-dangling-account</Type>
        <Email>{ string($person/Information/Contacts/Email) }</Email>
        <Creation Id="{ $person/Id }"> { string($person/@Creation) }</Creation>
      </Entry>
    return
      (
        system:as-user(account:get-secret-user(), account:get-secret-password(),xdb:remove($col-uri, $file)),
        if (exists($uname)) then (: FIXME: useless, dangling have no user name ? :)
          system:as-user(account:get-secret-user(), account:get-secret-password(),xdb:delete-user(normalize-space(string($uname))))
        else
          (),
        $entry
      )[last()]
};

(: ======================================================================
   Removes accounts where the user was not accepted after some delay
   TODO: 
    - create a delay parameter somewhere (job parameter ? settings.xml ?) 
    - define an email flow to remind coach a few days before ?
   ====================================================================== 
:)
declare function check:remove-account-without-submission( $threshold as xs:dayTimeDuration ) as element()* {
  for $person in fn:collection($globals:persons-uri)//Person
  let $uname := string($person/UserProfile/Username)
  where (count($person//Hosts//AccreditationRef) eq 0) and check:can-delete($person, $threshold)
  return
    let $col-name := misc:gen-collection-name-for(number($person/Id))
    let $col-uri := concat($globals:persons-uri,'/', $col-name)
    let $file := concat($person/Id,'.xml')
    let $entry :=
      <Entry>
        <Type>delete-no-acceptance-account</Type>
        { $person/Information/Contacts/Email }
        <Creation Id="{ $person/Id }">{ string($person/@Creation) }</Creation>
      </Entry>
    return
      (
        system:as-user(account:get-secret-user(), account:get-secret-password(),xdb:remove($col-uri, $file)),
        system:as-user(account:get-secret-user(), account:get-secret-password(),xdb:delete-user(normalize-space($uname))),
        $entry
      )[last()]
};
