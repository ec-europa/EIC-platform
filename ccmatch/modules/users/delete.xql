xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to delete a Person.

   March 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace system = "http://exist-db.org/xquery/system";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://oppidoc.com/ns/account" at "../users/account.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Checks that deleting $person is compatible with current DB state
   Returns aggregated error message or empty sequence
   ======================================================================
:)
declare function local:validate-person-delete( $id as xs:string, $person as element() ) as element()* {
  let $login := if (empty($person/UserProfile/Username)) then
                  ()
                else
                  ajax:throw-error('PERSON-WITH-LOGIN', ())
  return
    let $errors := ($login)
    return
      if (count($errors) > 0) then
        let $explain :=
          string-join(
            for $e in $errors
            return $e/message/text(), '. ')
        return
          oppidum:throw-error('DELETE-PERSON-FORBIDDEN', (display:gen-person-name($person, 'en'), $explain))
      else
        ()
};

(: ======================================================================
   Delete person from the database
   Do not use this function to delete a person with a login since it will
   not delete the login
   NOTE: currently if the last person is deleted, the next person
   that will be created will get the same Id since we do not memorize a LastIndex
   TODO: factorize with coaches/delete.xql ?
   ======================================================================
:)
declare function local:delete-person( $person as element() ) as element()* {
  let $result :=
    (
    <Table>user</Table>,
    <Action>delete</Action>,
    <Users><Id>{string($person/Id)}</Id></Users>
    )
  return
    let $name := concat($person/Information/Name/FirstName, ' ', $person/Name/LastName)
    let $col-name := misc:gen-collection-name-for(number($person/Id))
    let $del-res :=
      ( 
      let $cv-uri := misc:create-collection-lazy($globals:persons-cv-uri, $col-name, 'admin', 'users', 'rwxrwxr-x')
      let $file := $person/Resources/CV-File
      let $file-ref := string($person/Resources/CV-File)
      return
        if (exists($file)) then
          (
          update delete $file,
          if (util:binary-doc-available(concat($cv-uri, '/', $file-ref))) then
            system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:remove($cv-uri, $file-ref))
          else
            ()
          )
        else
          (),
      let $photo-uri := misc:create-collection-lazy($globals:persons-photo-uri, $col-name, 'admin', 'users', 'rwxrwxr-x')
      let $file := $person/Resources/Photo
      let $file-ref := string($person/Resources/Photo)
      let $file-ref-thumb := concat(substring-before($file-ref, '.'), '-thumb.', substring-after($file-ref, '.'))
      return
        if (exists($file)) then
          (
          update delete $file,
          if (util:binary-doc-available(concat($photo-uri, '/', $file-ref))) then
            system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:remove($photo-uri, $file-ref))
          else
            (),
          if (util:binary-doc-available(concat($photo-uri, '/', $file-ref-thumb))) then
            system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:remove($photo-uri, $file-ref-thumb))
          else
            ()
          )
        else
          ())
    let $col-uri := concat($globals:persons-uri,'/', $col-name)
    let $file := concat($person/Id,'.xml')
    return (
      system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:remove($col-uri, $file)),
      ajax:report-success('DELETE-PERSON-SUCCESS', $name, $result)
      )
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $person-ref := tokenize($cmd/@trail,'/')[3] (: NOTE: mapping dependant ! :)
let $person := fn:collection($globals:persons-uri)//Person[Id eq $person-ref]
(:let $lang := string($cmd/@lang):)
return
  if ($person) then (: sanity check :)
    if (access:user-belongs-to('admin-system')) then (: 1. check authorized user ? :)
      let $errors := local:validate-person-delete($person-ref, $person)  (: 2. compatible database state ? :)
      return
        if (empty($errors)) then
          if (($m = 'DELETE') or 
              (($m = 'POST') and (request:get-parameter('_delete', ()) eq "1"))) then (: real delete  :)
            local:delete-person($person)
          else if ($m = 'POST') then (: delete pre-step - we use POST to avoid forgery - :)
            ajax:report-success('DELETE-PERSON-CONFIRM', display:gen-person-name($person, 'en'))
          else
            ajax:throw-error('URI-NOT-FOUND', ())
        else
          $errors
    else
      ajax:throw-error('FORBIDDEN', ())
  else
    ajax:throw-error('URI-NOT-FOUND', ())

