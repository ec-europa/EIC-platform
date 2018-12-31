xquery version "1.0";
(: --------------------------------------
   Coach Match application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Controller for a coach to delete his/her profile himself

   Pre-condition: user token in URL must be user's database internal id

   Implements [Yes, remove my profile from Coach Match] button
   (DEPRECATED: [Delete my account] while registering new profile)

   See also modules/users/delete.xql

   TODO:
   - prevent latest system administrator to delete himself
   - personalize confirmation message

   March 2016 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace system = "http://exist-db.org/xquery/system";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace account = "http://oppidoc.com/ns/account" at "../users/account.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Delete the user in database and application
   Actually only temporary accounts are physically deleted (DEPRECATED)
   other accounts are either physically deleted or moved to a /db/trash 
   collection if available
   ======================================================================
:)
declare function local:delete-profile( $person as element(), $is-temp as xs:boolean ) {
  let $uname := string($person/UserProfile/Username)
  let $fname := display:gen-person-name($person, 'en')
  let $cmd := oppidum:get-command()
  return
    let $col-name := misc:gen-collection-name-for(number($person/Id))
    let $col-uri := concat($globals:persons-uri,'/', $col-name)
    let $file := concat($person/Id,'.xml')
    return (
      misc:delete-resource($globals:persons-cv-uri, $col-name, $person/Resources/CV-File, ()),
      misc:delete-resource($globals:persons-photo-uri, $col-name, $person/Resources/Photo, '-thumb'),
      if ($is-temp) then (: DEPRECATED :)
        system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:remove($col-uri, $file))
      else if (xdb:collection-available('/db/trash')) then (: move to trash if available :)
        (
        person:goto-next-status($person, true()),
        (: change name to avoid unprobable name conflict since Id can be reassigned :)
        let $archive := concat($person/Id, '-', replace(substring(string(current-dateTime()), 1, 19), ':', '-'), '.xml')
        return (
          xdb:rename($col-uri, $file, $archive),
          xdb:move($col-uri, '/db/trash', $archive)
          )
        )
      else (: permanent delete :)
        system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:remove($col-uri, $file)),
      if (($uname ne '') and xdb:exists-user($uname)) then (: deletes eXist-DB user if it exists :)
        system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:delete-user(normalize-space($uname)))
      else
        (),
      ajax:report-success-redirect('PROFILE-DELETED',
        if ($is-temp) then $fname else $uname, 
        concat($cmd/@base-url, if ($is-temp) then 'login' else 'logout')
        )
      )[last()]
};

(: *** MAIN ENTRY POINT *** :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $person-ref := tokenize($cmd/@trail,'/')[1] (: NOTE: mapping dependant ! :)
let $person := fn:collection($globals:persons-uri)//Person[$person-ref = (Id, Information/Uuid)]
let $user := oppidum:get-current-user()
let $tmp-user := exists($person/Information/Uuid)
return
  if ($person) then (: sanity check :)
    (: 1. check authorized user or token generated at registration :)
    if ($user = ($person/UserProfile/Username, $person/UserProfile/Remote) or $person/Information/Uuid) then 
      if (($m = 'POST') and (request:get-parameter('_delete', ()) eq "1")) then 
        (: 3. real delete  :)
        local:delete-profile($person, $tmp-user)
      else if ($m = 'POST') then 
        (: 2. delete pre-step - POST to avoid basic forgery :)
        if ($tmp-user) then
          ajax:report-success('SELF-DELETE-ACCOUNT-CONFIRM', ())
        else
          ajax:report-success('SELF-DELETE-PERSON-CONFIRM', ())
      else
        ajax:throw-error('URI-NOT-FOUND', ())
    else
      ajax:throw-error('FORBIDDEN', ())
  else
    ajax:throw-error('URI-NOT-FOUND', ())

