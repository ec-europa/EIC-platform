xquery version "3.1";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to read/write user's photo

   See also cv.xql

   FIXME:
   - remove access control to speed up lookup (?)

   November 2015 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace photo = "http://oppidoc.com/oppidum/photo" at "../../lib/photo.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../../xcm/lib/database.xqm";

(: FIXME: must be html and no xml to be compatible with DropZone read mode :)
declare option exist:serialize "method=html media-type=text/html indent=no";

(: Counter index for naming Photo files :)
declare variable $photo-counter-name := 'photo-next-id';

(: Accepted file extensions normalized to construct an image/"ext" Mime Type string :)
declare variable $accepted-extensions := ('jpeg', 'jpg', 'png', 'tif', 'tiff', 'gif');


(: ======================================================================
   Creates the $path hierarchy of collections directly below the $base-uri collection.
   The $path is a relative path not starting with '/'
   The $base-uri collection MUST be available.
   Returns the database URI to the terminal collection whatever the outcome.
   ======================================================================
:)
declare function local:create-collection-lazy ( $base-uri as xs:string, $path as xs:string, $user as xs:string, $group as xs:string, $perms as xs:string ) as xs:string*
{
  let $set := tokenize($path, '/')
  return (
    for $t at $i in $set
    let $parent := concat($base-uri, '/', string-join($set[position() < $i], '/'))
    let $path := concat($base-uri, '/', string-join($set[position() < $i + 1], '/'))
    return
     if (xdb:collection-available($path)) then
       ()
     else
       if (xdb:collection-available($parent)) then
         if (xdb:create-collection($parent, $t)) then
           custom:set-owner-group-permissions($path, $user, $group, $perms)
         else
           ()
       else
         (),
    concat($base-uri, '/', $path)
    )[last()]
};

declare function local:report-plugin-error( $id as xs:string, $msg as xs:string ) as element() {
  let $exec := response:set-header('Content-Type', 'text/xml; charset=UTF-8')
  let $status := response:set-status-code(500)
  return
    <Payload>
      <Id>{ $id }</Id>
      <error>
        <message>{ $msg }</message>
      </error>
    </Payload>
};

declare function local:report-plugin-success( $id as xs:string, $path as xs:string ) as element() {
  let $exec := response:set-header('Content-Type', 'text/xml; charset=UTF-8')
  return
    <Payload>
      <Id>{ $id }</Id>
      <success>
        <message>{ $path }</message>
      </success>
    </Payload>
};

(: ======================================================================
   Create and add a Binary element to the Binaries catalog inside $enterprise
   Lazy creation of Binaries
   ====================================================================== 
:)
declare function local:create-binary( $size as xs:string, $filename as xs:string, $type as xs:string, $extension as xs:string, $enterprise as element() ) as xs:integer {
  (# exist:batch-transaction #) {
    if (exists($enterprise/Binaries)) then
      let $id := xs:integer($enterprise/Binaries/@LastIndex) + 1
      return (
        update insert <Binary Id="{ $id }" Filesize="{ $size }" Filename="{ $filename }" TS="{ string(current-dateTime()) }" Type="{ $type }">{ $id }.{ $extension }</Binary> into $enterprise/Binaries,
        update value $enterprise/Binaries/@LastIndex with string($id),
        $id
        )
    else (
      update insert <Binaries LastIndex="1"><Binary Id="1" Filesize="{ $size }" Filename="{ $filename }" TS="{ string(current-dateTime()) }" Type="{ $type }">1.{ $extension }</Binary></Binaries> into $enterprise,
      1
      )
  }
};

declare function local:create-resource( $type as xs:string, $storekey as xs:string, $event as element() ) {
  let $resource := <Resource Type="{ $type }">{ $storekey }</Resource>
  return
    if (exists($event/Resources)) then
      update insert $resource into $event/Resources
    else
      update insert <Resources>{ $resource }</Resources> into $event
};

(: =====================================================================in
   Upload photo posted with AXEL 'photo' plugin protocol (classical form upload)
   Uploaded photo will be named $id and stored inside parent collection
   NOTE: save meta-data before actually saving binary data to be support
   multiple parallel writes (e.g. drag and dropping multiple files at same time)
   ======================================================================
:)
declare function local:upload-photo ( $col-uri as xs:string, $enterprise as element(), $event as element(), $type as xs:string ) {
  let $data := request:get-uploaded-file-data('xt-photo-file')
  let $size := request:get-uploaded-file-size('xt-photo-file')
  let $perms := 'rwxrwxr--'
  return
    (: TODO: check $data is a binary stream ? :)
    if (true()) then
      (: check photo binary stream has compatible MIME-TYPE :)
      let $filename := request:get-uploaded-file-name('xt-photo-file')
      let $extension:= misc:get-extension($filename)
      let $mime-error := misc:check-extension($extension, $accepted-extensions)
      return
        if (exists($mime-error)) then
          local:report-plugin-error(0, $mime-error)
        else
          (: saves meta-data first to avoid interleaving if multiple // writes :)
          let $id := local:create-binary($size, $filename, $type, $extension, $enterprise)
          (: photo:write saves as $storekey, this operation may take time ? :)
          let $storekey := photo:write($col-uri, 'admin', 'users', $data, $id, $extension, $perms)
          return
            if ($storekey) then (
              local:create-resource($type, $storekey, $event),
              local:report-plugin-success( $id, $storekey)
              )
            else
              (: FIXME: ideally we should delete Binary ? :)
              local:report-plugin-error( $id, "Error while writing image file, please try another one")
    else
      local:report-plugin-error(0, "Invalid file : not a binary file")
};

(: ======================================================================
   Streams photo file requested by command
   ====================================================================== 
:)
declare function local:open-file( $cmd as element() ) {
  let $filename := concat($cmd/resource/@name, '.', $cmd/@format)
  let $col-uri :=  custom:get-enterprises-binary-uri(tokenize($cmd/@trail, '/')[2])
  let $file-uri := concat($col-uri, '/', $filename)
  return
    if (util:binary-doc-available($file-uri)) then
      misc:get-binary-file($file-uri, concat('image/', $cmd/@format), 'private')
    else
      oppidum:throw-error('CUSTOM', concat($filename, ' not found'))
};

(: ======================================================================
   Returns an List XML model of the photo resources to load in 
   AXEL-FORMS "dropzone" plugin.
   ====================================================================== 
:)
declare function local:get-thumbnails-for-event( $cmd as element(), $event-id as xs:string, $type as xs:string ) as element() {
  let $eid := tokenize($cmd/@trail, '/')[2]
  let $enterprise := globals:collection('enterprises-uri')//Enterprise[Id eq $eid]
  let $event :=  $enterprise//Event[Id eq $event-id]
  return
    <List>
    {
      for $res in $event/Resources/Resource[lower-case(@Type) eq $type or $type eq '']
      let $filename := $res/text()
      group by $filename (: added to be robust to duplicates - e.g. SMEIMKT-633 :)
      return
        let $bin := fn:head($enterprise/Binaries/Binary[text() = $filename])
        return
          <File>
          { 
            $bin/@Id,
            $bin/@Filename, 
            $bin/@Filesize,
            let $col-uri := custom:get-enterprises-binary-uri($eid)
            let $file := concat(substring-before($filename, '.'), '.', substring-after($filename, '.'))
            let $thumb-file := concat(substring-before($filename, '.'), '-thumb.', substring-after($filename, '.'))
            return
              attribute URI { concat($cmd/@base-url, 'enterprises/', tokenize($cmd/@trail, '/')[2], '/binaries/', 
                if (util:binary-doc-available( concat($col-uri, '/', $thumb-file) )) then $thumb-file else $file)
              }
          }
          </File>
    }
    </List>
};

(: ======================================================================
   Delete (photo) resource from target enterprise in path second segment :
   - binary file
   - first corresponding Binary element in global Binaries enterprise register
   - first corresponding Resource element in local Resources event register
   Delete only existing file / first elements to better resists to corrupted records
   ====================================================================== 
:)
declare function local:delete-resource-for-event( $cmd as element(), $resource as xs:string, $event-id as xs:string ) as element()* {
  let $enterprise := globals:collection('enterprises-uri')//Enterprise[Id eq tokenize($cmd/@trail, '/')[2]]
  (: should be unique but take the first for sanity - see SMIMKT-633 bug :)
  let $binary := fn:head($enterprise/Binaries/Binary[@Id eq $resource]) 
  return 
    let $filename := $binary/text()
    let $key := concat($resource, '.')
    let $inevent :=  $enterprise//Event[Id eq $event-id]//Resource[starts-with(.,$key)]
    let $col-uri := custom:get-enterprises-binary-uri(tokenize($cmd/@trail, '/')[2])
    return
      (: FIXME: handle errors - e.g. /db/null :)
      if (true()) then
        (
        if (exists($filename)) then (
          if (util:binary-doc-available(concat($col-uri, '/', $filename))) then
            xdb:remove($col-uri, $filename)
          else
            (),
          let $thumb-file := concat(substring-before($filename, '.'), '-thumb.', 
                                    substring-after($filename, '.'))
          return
            if (util:binary-doc-available(concat($col-uri, '/', $thumb-file))) then
              xdb:remove($col-uri, $thumb-file)
            else
              ()
          )
        else
          (),
        update delete $inevent,
        update delete $binary,
        <success/>
        )[last()]
      else
        <error/>
};

let $cmd := request:get-attribute('oppidum.command')
let $enterprise-id := tokenize($cmd/@trail, '/')[2]
let $event-id := tokenize($cmd/@trail, '/')[4]
let $resource := $cmd/resource/@name
let $enterprise := globals:collection('enterprises-uri')//Enterprise[Id eq $enterprise-id]
let $event := $enterprise//Event[Id eq $event-id]
(: FIXME: harden access control :)
let $access := access:get-entity-permissions('view', 'Enterprise', $enterprise)
let $m := request:get-method()
return
  if ($m eq 'POST') then
    if (local-name($access) eq 'allow') then
      let $col-uri := custom:get-enterprises-binary-uri(tokenize($cmd/@trail, '/')[2])
      return
        if ($col-uri ne '/db/null') then
          let $path := local:create-collection-lazy('/db', substring-after($col-uri, '/db'), 'admin', 'users', 'rwxrwxr--')
          return
            let $type := if ($resource eq 'logo') then 'Logo' else if ($resource eq 'photo') then 'Photo' else 'Binary'
            return
              if ($path ne '') then
              
                local:upload-photo($path, $enterprise, $event, $type)
              else
                ()
        else
          oppidum:throw-error("INTERNAL-ERROR", ())
    else
      $access
  else
    if (local-name($access) eq 'allow') then
      if ($resource eq 'list') then
        let $event-id := request:get-parameter('event', '0')
        let $type := request:get-parameter('type', '')
        return
          local:get-thumbnails-for-event( $cmd, $event-id, $type )
      else if ($resource eq 'delete') then
        let $event-id := request:get-parameter('event', '0')
        return
          local:delete-resource-for-event( $cmd, tokenize($cmd/@trail, '/')[4], $event-id )
      else
        local:open-file($cmd)
    else
      $access
