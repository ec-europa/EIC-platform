xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Manages Time sheet files upload.

   Accepts some parameters from mapping:
   - group (TO BE DONE)

   Hard-coded parameters:
   - collection to contain files is called 'docs'
   - permissions on both is set to 0744 (rwuw--r--)
   - permission on uploaded file (TO BE DONE)

   !!! Due to an eXist bug, it is not possible yet to pass parameter trough request's parameters.
   Request's attributes are used instead. FIXME: does it still applies to versions >= 1.41. ?

   March 2012 - (c) Copyright may be reserved
   ------------------------------------------------------------------ :)

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace image = "http://exist-db.org/xquery/image";
import module namespace util = "http://exist-db.org/xquery/util";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../../oppidum/lib/compat.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";

declare option exist:serialize "method=text media-type=text/plain indent=no";

(: Counter index for naming time sheet files :)
declare variable $ts-counter-name := 'ts-next-id';

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
      compat:set-owner-group-permissions(concat($col-uri, '/', $filename), $user, $group, $perms),
      $filename
      )
    else
      ()
};

(: ======================================================================
   
   ======================================================================
:)
declare function local:upload-file( $col-uri as xs:string, $host as element(), $counter-host as element(), $name as xs:string ) as xs:string {
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
            let $id := misc:increment-variable($ts-counter-name, $counter-host)
            let $res := local:write-file($col-uri, 'admin', 'users', $id,  $data, $extension, "rwxrwxr-x")
            return
              if ($res) then (
                misc:update-resource($col-uri, $res, $name, $host, ()),
                ajax:report-file-plugin-success($res, 201)
                )
              else
                ajax:report-file-plugin-error("Error while writing PDF file, please try another one", 500)
          else
            ajax:report-file-plugin-error(concat("Server failed to create collection ", $col-uri, " to store image"), 500)
          (: TBD: update experiences  :)
        else
          ajax:report-file-plugin-error($mime-error, 400)
    else
      ajax:report-file-plugin-error("Invalid file : not a binary file", 400)
};

(: ======================================================================
   Removes binary file referenced by element name of Resources model of host element
   and stored in col-uri collection, and removes its reference from host element too
   TODO: check the POST <Delete> target is identitical to file ref ?
   ======================================================================
:)
declare function local:delete-file( $col-uri as xs:string, $host as element(), $name as xs:string ) as element() {
  let $file := $host/Resources/*[local-name(.) eq $name]
  let $file-ref := string($file)
  return
    if (exists($file)) then
      (
      update delete $file,
      if (util:binary-doc-available(concat($col-uri, '/', $file-ref))) then
        xdb:remove($col-uri, $file-ref)
      else
        (),
      oppidum:throw-message('ACTION-DELETE-SUCCESS', $file-ref)
      )
    else
      oppidum:throw-error('FILE-NOT-FOUND', ('Timesheet file', 'activity'))
};

(:::::::::::::  BODY  ::::::::::::::)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $case := $project/Cases/Case[No eq $case-no]
let $activity-no := tokenize($cmd/@trail,'/')[6]
let $activity := $case/Activities/Activity[No = $activity-no]
let $goal :=
  if (($cmd/@action eq 'remove') and ($m eq 'POST')) then
    'delete'
  else if ($m eq 'POST') then
    'update'
  else
    'read'
let $errors := access:pre-check-activity($project, $case, $activity, $m, $goal, 'TimesheetFile')
return
  if (empty($errors)) then
    let $col-name := substring-after(util:collection-name($project), '/projects/')
    return
      if ($goal eq 'delete') then
        let $col-uri := misc:create-collection-lazy($globals:timesheets-uri, $col-name, 'admin', 'users')
        return (
          util:declare-option("exist:serialize", "method=xml media-type=text/xml"),
          local:delete-file($col-uri, $activity, 'TimesheetFile')
          )
      else if ($goal eq 'update') then
        let $col-uri := misc:create-collection-lazy($globals:timesheets-uri, $col-name, 'admin', 'users')
        return local:upload-file($col-uri, $activity, $case, 'TimesheetFile')
      else (: assume 'read' :)
        let $file-uri := concat($globals:timesheets-uri, '/', $col-name, '/', $cmd/resource/@name, '.', $cmd/@format)
        return misc:get-binary-file($file-uri, concat('application/', $cmd/@format), ())
  else (: TODO: convert error to AXEL 'file' plugin protocol ? :)
    $errors
