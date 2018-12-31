xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Manages CV files upload.

   Accepts some parameters from mapping:
   - group (TO BE DONE)

   See also photo.xql

   FIXME: 
   - no fine grain access control when called as guest 
     by external application, eventually replace with a POST /cv/open 
     using service API and Host key to apply coaches preferences
     (actually only protected by test on Referer)
   - hard coded permissions 0774 on collection and uploaded file

   July 2016 - (c) Copyright may be reserved
   ------------------------------------------------------------------ :)

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace image = "http://exist-db.org/xquery/image";
import module namespace text = "http://exist-db.org/xquery/text";
import module namespace util = "http://exist-db.org/xquery/util";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../../oppidum/lib/compat.xqm";

declare option exist:serialize "method=text media-type=text/plain indent=no";

(: Counter index for naming CV files :)
declare variable $cv-counter-name := 'cv-next-id';

(: Accepted file extensions normalized to construct an application/"ext" Mime Type string :)
declare variable $accepted-extensions := ('pdf');

(: ======================================================================
   Writes binary file to target collection
   ======================================================================
:)
declare function local:write-file(
  $col-uri as xs:string,
  $user as xs:string,
  $group as xs:string,
  $id as xs:string,
  $data as xs:base64Binary,
  $extension as xs:string,
  $perms as xs:string ) as xs:string?
{
  let $filename := concat(normalize-space($id), '.', $extension)
  let $mime-type := concat('application/', $extension)
  return
    if (xdb:store($col-uri, $filename, $data, $mime-type)) then (
      compat:set-owner-group-permissions(concat($col-uri,'/', $filename), $user, $group, $perms),
      $filename
      )
    else
      ()
};

(: ======================================================================
   TODO: manage case without xt-file-id (i.e. no preflight)
   ======================================================================
:)
declare function local:upload-file( $col-uri as xs:string, $person as element() ) as xs:string {
  (: get uploaded file binary stream :)
  let $data := request:get-uploaded-file-data('xt-file')
  return
    if ($data instance of xs:base64Binary) then
      (: check file binary stream has compatible MIME-TYPE :)
      let $filename := request:get-uploaded-file-name('xt-file')
      (: TODO : check request:get-uploaded-file-size('xt-file') for limit !!! :)
      let $extension := misc:get-extension($filename)
      let $mime-error := misc:check-extension($extension, $accepted-extensions)
      return
        if (empty($mime-error)) then
          if (xdb:collection-available($col-uri)) then
            let $id := misc:increment-variable($cv-counter-name)
            let $res := local:write-file($col-uri, 'admin', 'users', $id,  $data, $extension, 'rwxrwxr--')
            return
              if ($res) then (
                misc:update-resource($col-uri, $res, 'CV-File', $person, ()),
                ajax:report-file-plugin-success($res, 201)
                )
              else
                ajax:report-file-plugin-error("Error while writing PDF file, please try another one", 500)
          else
            ajax:report-file-plugin-error("Server failed to create collection to store image", 500)
          (: TBD: update experiences  :)
        else
          ajax:report-file-plugin-error($mime-error, 400)
    else
      ajax:report-file-plugin-error("Invalid file : not a binary file", 400)
};

(: ======================================================================
   Removes current Person's cv binary file from cv collection and removes
   its reference from Person's Resources model
   TODO: check the POST <Delete> target is identitical to file ref ?
   ======================================================================
:)
declare function local:delete-file( $col-uri as xs:string, $person as element() ) as element() {
  let $file := $person/Resources/CV-File
  let $file-ref := string($person/Resources/CV-File)
  return
    if (not($person//CV-Link)) then
      oppidum:throw-error('APPLICATION-KEEP-EITHER-CV', ())
    else if (exists($file)) then
      (
      update delete $file,
      if (util:binary-doc-available(concat($col-uri, '/', $file-ref))) then
        xdb:remove($col-uri, $file-ref)
      else
        (),
      oppidum:throw-message('ACTION-DELETE-SUCCESS', $file-ref)
      )
    else
      oppidum:throw-error('CV-FILE-NOT-FOUND', ())
};

(: ======================================================================
   Streams CV file requested by command for given coach
   ====================================================================== 
:)
declare function local:open-file( $person as element(), $cmd as element() ) {
  let $filename := concat($cmd/resource/@resource, '.', $cmd/@format)
  return
    if ($filename eq $person/Resources/CV-File) then
      let $col-name := misc:gen-collection-name-for(number($person/Id))
      let $file-uri := concat($globals:persons-cv-uri, '/', $col-name, '/', $filename)
      return misc:get-binary-file($file-uri, concat('application/', $cmd/@format), ())
    else
      oppidum:throw-error('NOT-FOUND', ())
};

(:::::::::::::  BODY  ::::::::::::::)
let $cmd := request:get-attribute('oppidum.command')
let $token := tokenize($cmd/@trail, '/')[1]
let $user := oppidum:get-current-user()
let $groups := oppidum:get-user-groups($user, oppidum:get-current-user-realm())
let $m := request:get-method()
return
  if ($m eq 'POST') then (: upload or delete CV :)
    let $person := access:get-person($token, $user, $groups)
    return
      if (local-name($person) ne 'error') then
        let $col-name := misc:gen-collection-name-for(number($person/Id))
        return
          if (($cmd/@action eq 'remove') and ($m eq 'POST')) then
            let $col-uri := misc:create-collection-lazy($globals:persons-cv-uri, $col-name, 'admin', 'users', 'rwxrwxr-x')
            return (
              util:declare-option("exist:serialize", "method=xml media-type=text/xml"),
              local:delete-file($col-uri, $person)
              )
          else
            let $col-uri := misc:create-collection-lazy($globals:persons-cv-uri, $col-name, 'admin', 'users', 'rwxrwxr-x')
            return local:upload-file($col-uri, $person)
      else (: TODO: convert error to AXEL 'file' plugin protocol ? :)
        $person
  else (: assume GET :)
    if ($user ne 'guest') then (: authentified user calling from Coach Match search :)
      let $person := access:get-person-from-host($token, $user, $groups, '0')
      return
        if (local-name($person) ne 'error') then
          local:open-file($person, $cmd)
        else
          $person
    else (: calling from 3rd party application :)
      let $person := access:get-person-nonce($token, $user, $groups)
      (: FIXME: access:get-person-from-host($token, HOST KEY ?) :)
      return 
        if (local-name($person) ne 'error') then
          local:open-file($person, $cmd)
        else
          $person
