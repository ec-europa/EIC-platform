xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to read/write user's photo

   See also cv.xql

   FIXME:
   - remove access control to speed up lookup (?)

   November 2015 - (c) Copyright may be reserved
   -------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace photo = "http://oppidoc.com/oppidum/photo" at "../../lib/photo.xqm";

declare option exist:serialize "method=html media-type=text/html indent=no";

(: Counter index for naming Photo files :)
declare variable $photo-counter-name := 'photo-next-id';

(: Accepted file extensions normalized to construct an image/"ext" Mime Type string :)
declare variable $accepted-extensions := ('jpeg', 'png');

(: ======================================================================
   Upload photo posted with AXEL 'photo' plugin protocol (classical form upload)
   Uploaded photo will be named $id and stored inside parent collection
   ======================================================================
:)
declare function local:upload-photo ( $col-uri as xs:string, $person as element() ) {
  let $data := request:get-uploaded-file-data('xt-photo-file')
  let $perms := 'rwxrwxr--'
  return
    if (true()) then
      (: check photo binary stream has compatible MIME-TYPE :)
      let $filename := request:get-uploaded-file-name('xt-photo-file')
      let $extension:= misc:get-extension($filename)
      let $mime-error := misc:check-extension($extension, $accepted-extensions)
      return
        if (empty($mime-error)) then
          let $id := misc:increment-variable($photo-counter-name)
          let $res := photo:write($col-uri, 'admin', 'users', $data, $id, $extension, $perms)
          return
            if ($res) then (
              misc:update-resource($col-uri, $res, 'Photo', $person, '-thumb'),
              ajax:report-photo-plugin-success($res)
              )
            else
              ajax:report-photo-plugin-error("Error while writing image file, please try another one")
        else
          ()
    else
      ajax:report-photo-plugin-error("Invalid file : not a binary file")
};

(: ======================================================================
   Streams photo file requested by command for given coach
   ====================================================================== 
:)
declare function local:open-file( $person as element(), $cmd as element() ) {
  let $filename := concat($cmd/resource/@resource, '.', $cmd/@format)
  return
    if ($filename eq $person/Resources/Photo) then
      let $col-name := misc:gen-collection-name-for(number($person/Id))
      let $file-uri := concat($globals:persons-photo-uri, '/', $col-name, '/', $filename)
      return misc:get-binary-file($file-uri, concat('image/', $cmd/@format), 'private')
    else
      oppidum:throw-error('NOT-FOUND', ())
};

let $cmd := request:get-attribute('oppidum.command')
let $token := tokenize($cmd/@trail, '/')[1]
let $user := oppidum:get-current-user()
let $groups := oppidum:get-current-user-groups()
let $m := request:get-method()
return
  if ($m eq 'POST') then
    let $person := access:get-person($token, $user, $groups)
    return
      if (local-name($person) ne 'error') then
        let $col-name := misc:gen-collection-name-for(number($person/Id))
        let $col-uri := misc:create-collection-lazy($globals:persons-photo-uri, $col-name, 'admin', 'users', 'rwxrwxr-x')
        return 
          local:upload-photo($col-uri, $person)
      else (: TODO: convert error to AXEL 'photo' plugin protocol :)
        $person
  else
    if ($user ne 'guest') then (: authentified user calling from Coach Match search :)
      let $person := access:get-person-from-host($token, $user, $groups, '0')
      return
        if (local-name($person) ne 'error') then
          local:open-file($person, $cmd)
        else
          $person
    else (: calling from 3rd party application :)
      let $person := access:get-person($token, $user, $groups)
      (: FIXME: access:get-person-from-host($token, HOST KEY ?) :)
      return 
        if (local-name($person) ne 'error') then
          local:open-file($person, $cmd)
        else
          $person
