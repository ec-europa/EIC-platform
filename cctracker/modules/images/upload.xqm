xquery version "1.0";
(: ------------------------------------------------------------------
   Oppidum module: image

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Manages photo upload

   Note that for some images the function get-height, get-width or scale print an error and do
   nothing, This happen for instance if they are in CYMK color space, in that case the script
   does not create a thumb.

   Mapping's level parameters:
   - logo-thumb-size (HxW)
   - photo-thumb-size (HxW)
   - max-size (HxW) : scales image to that size if it is bigger
   - thumb ("explicit") : when set to "explicit" photo-thumb-size is applied 
     on a per-request basis if and only if request's ?thumb parameter is set (any value)
   
   Request's level parameters:
   - thumb=* : asks explicitly for thumb create when mapping's thumb parameter is set 
     to explicit and when mapping's photo-thumb-size is defined 

   Hard-coded parameters:
   - collection to contain images is called 'images'
   - image collection index is called 'index.xml'
   
   TODO:
   - split max-size into logo-max-size and photo-max-size for independent control (?)

   February 2012 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace osimg = "http://oppidoc.com/oppidum/images";

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace image = "http://exist-db.org/xquery/image";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";

(: Accepted file extensions normalized to construct an image/"ext" Mime Type string :)
declare variable $osimg:accepted-extensions := ('jpeg', 'png', 'gif');

declare function osimg:get-extension( $file-name as xs:string ) as xs:string
{
  let $unparsed-extension := lower-case( (analyze-string($file-name, '\.(\w+)')//fn:group)[last()] )
  return
    replace(replace($unparsed-extension, 'jpg', 'jpeg'), 'tif', 'tiff')
};

(:
  Checks extension is a compatible image type.
  Returns 'ok' or an error message.
:)
declare function osimg:check-extension( $ext as xs:string ) as xs:string
{
  if ( empty(fn:index-of($osimg:accepted-extensions, $ext)) )
  then concat('Les images format ', $ext, ' ne sont actuellement pas supportées')
  else 'ok'
};

(: ======================================================================
   Bootstrap method to create an 'index.xml' file starting at latest index
   inside an images collection that doesn't have it yet (hot plug).
   Returns the first number after the bigger number used to name
   a file inside the collection or 1 if none.
   ======================================================================
:)
declare function osimg:get-free-resource-name( $col-uri as xs:string ) as xs:integer
{
  let $files := xdb:get-child-resources($col-uri)
  return
    if ((count($files) = 0) or ('index.xml' = $files)) then
       1
    else
      1 + max(
        (0, for $name in $files
        let $nb := analyze-string($name, '((\d+)(-logo)?\.\w{2,5})$')//fn:group[3]
        where $nb castable as xs:integer
        return xs:integer($nb)) )
};

(: ======================================================================
   Returns the current LastIndex in the images collection, creates it
   initialized to 1 if it does not exists. Returns empty sequence if
   the current LastIndex is not usable (this is a serious ERROR).
   ======================================================================
:)
declare function osimg:get-index( $col-uri as xs:string, $user as xs:string, $group as xs:string, $perms as xs:integer ) as node()?
{
  let $doc-uri := concat($col-uri, '/index.xml')
  return (
    if (not(doc-available($doc-uri))) then
      let $start := osimg:get-free-resource-name($col-uri)
      let $index := <Gallery LastIndex="{$start}"/> (: lazy creation :)
      return
        if (xdb:store($col-uri, 'index.xml', $index)) then (
          xdb:set-resource-permissions($col-uri, 'index.xml', $user, $group, $perms),
          oppidum:debug(('image/upload.xql created ', $doc-uri, ' with index ', string($start)))
          )
        else
          oppidum:debug(('image/upload.xql failed to create ', $doc-uri, ' with index ', string($start)))
    else (),
    doc($doc-uri)/Gallery/@LastIndex
    )[last()]
};

(: ======================================================================
   Creates the 'images' collection with an 'index.xml' resource with a
   LastIndex attribute inside the collection $col-uri if they do not
   already exist, returns the path to the created collection.
   ======================================================================
:)
declare function osimg:create-collection-lazy ( $col-uri as xs:string, $user as xs:string, $group as xs:string, $perms as xs:integer ) as xs:string*
{
  let $path := concat($col-uri, '/images')
  return
    if (not(xdb:collection-available($path))) then
      if (xdb:create-collection($col-uri, 'images')) then (
        xdb:set-collection-permissions($path, $user, $group, $perms),
        $path
        )[last()]
      else
        ()
    else
      $path
};

(: WARNING: as we use double-quotes to generate the Javascript string
   do not use double-quotes in the $msg parameter !
":)
declare function osimg:gen-error( $msg as xs:string ) as element() {
  let $exec := response:set-header('Content-Type', 'text/html; charset=UTF-8')
  return
    <html>
      <body>
        <script type='text/javascript'>window.parent.finishTransmission(0, "{$msg}")</script>
     </body>
    </html>
};

(:<script type='text/javascript'>window.parent.finishTransmission(1, {{url: "{$full-path}{$id}.{$ext}", resource_id: "{$id}"}})</script>:)
declare function osimg:gen-success( $id as xs:string, $ext as xs:string ) as element() {
  let
    $full-path := 'images/',
    $exec := response:set-header('Content-Type', 'text/html; charset=UTF-8')
  return
    <html>
      <body>
        <script type='text/javascript'>window.parent.finishTransmission(1, "{$full-path}{$id}.{$ext}")</script>
     </body>
    </html>
};

(: ======================================================================
   Converts a pre-defined request attribute representing a geometry string
   such as '100x200' (HxW) into a pair of integers. Return empty sequence
   if conversion fail or the attribute is missing from the request.
   ======================================================================
:)
declare function osimg:get-geometry( $name as xs:string ) as xs:integer*
{
  let $g := request:get-attribute(concat('xquery.', $name))
  return
    if ($g and ($g != 'unset')) then
      let $seq := tokenize($g, 'x')
      return
        if (($seq[1] castable as xs:integer) and ($seq[2] castable as xs:integer)) then
          (xs:integer($seq[1]), xs:integer($seq[2]))
        else
          oppidum:debug(('images/upload.xql has ignored wrong geometry (', $g, ') parameter'))
    else
      ()
};

(: ======================================================================
   Checks if the $data must be downscale according to the $constraint
   Returns a pair where the first item is true() if the $data has been
   downscaled and false otherwise, and the second item is the $data if
   no downscaling was required or either the result of downscaling
   if it succeeded or () otherwise
   ======================================================================
:)
declare function osimg:downscale( $constraint as xs:string, $id as xs:string, $mime-type as xs:string, $data as xs:base64Binary ) as item()*
{
  let $max-size := osimg:get-geometry($constraint)
  return
    if (count($max-size) > 1) then
      let $width := image:get-width($data)
      let $height := if ($width) then image:get-height($data) else ()
      let $need-scaling := ($width and $height) and (($width > $max-size[1]) or ($height > $max-size[2]))
      let $log := oppidum:debug(('image/upload.xql found image ', string($id), ' dimensions ', string($width), 'x', string($height), ' needs scaling to ', $constraint, '(', string($max-size[1]), 'x', string($max-size[2]), ')', ' is ', string($need-scaling)))
      return
        if ($need-scaling) then
          let $res := image:scale($data, $max-size, $mime-type)
          return
            if ($res instance of xs:base64Binary) then
              (true(), $res)
            else
              (true(), ()) (: failure while downscaling :)
        else
          (false(), $data) (: no need to dowscale :)
    else
      (false(), $data) (: no need to dowscale :)
};

(: ======================================================================
   Creates the image file into the database and update the LastIndex
   Generates the file name from the $cur-index.
   Pre-condition: $cur-index attribute MUST contain a number
   ======================================================================
:)
declare function osimg:do-upload(
  $col-uri as xs:string,
  $user as xs:string,
  $group as xs:string,
  $cur-index as node(),
  $data as xs:base64Binary,
  $ext as xs:string,
  $perms as xs:integer ) as element()*
{
  let
    $isLogo := request:get-parameter('g', ()) = 'logo',
    $id := string($cur-index),
    $image-id := if ($isLogo) then concat($id, '-logo') else $id,
    $filename := concat($image-id, '.', $ext),
    $mime-type := concat('image/', $ext),
    $log := oppidum:debug(('image/upload.xqm creating image ', string($image-id), ' with mime-type ', string($mime-type))),
    $filtered := osimg:downscale('max-size', $image-id, $mime-type, $data)
  return
    if (($filtered[2] instance of xs:base64Binary) and (xdb:store($col-uri, $filename, $filtered[2], $mime-type))) then
      (
      xdb:set-resource-permissions($col-uri, $filename, $user, $group, $perms),
      update replace $cur-index with attribute LastIndex { number($id) +1 },
      (: prepare a thumb image if needed - note that we could release the exclusive lock now... :)
      let $cname := if ($isLogo) then 'logo-thumb-size' else 'photo-thumb-size'
      let $tryThumb := if ('explicit' = request:get-attribute('xquery.thumb')) then ('thumb' = request:get-parameter-names()) else true()
      let $thumb := if ($tryThumb) then osimg:downscale($cname, $image-id, $mime-type, $data) else ()
      return
        if (not(empty($thumb)) and $thumb[1] and ($thumb[2] instance of xs:base64Binary)) then (: write thumb :)
          if (xdb:store($col-uri, concat($image-id, '-thumb.', $ext), $thumb[2], $mime-type))
            then xdb:set-resource-permissions($col-uri, concat($image-id, '-thumb.', $ext), $user, $group, $perms)
            else () (: TODO: return a warning in case of error :)
        else (), (: skip it, either no need to create a thumb or failure :)
      osimg:gen-success(string($image-id), $ext)
      )[last()]
    else
      osimg:gen-error("Erreur lors de la sauvegarde de l'image, réessayez avec une autre")
};

(: ======================================================================
   Uploads an image into the reference collection
   Lazily creates the 'images' sub-folder if it does not exists
   Lazily creates the 'images/index.xml' if an 'images' folder alread exists
   The 'images' collection and all the resources permissions are initialized
   with the function parameters
   NB: use stg like  util:base-to-integer(0744, 8) to generate $perms integer
   ======================================================================
:)
declare function osimg:upload ( $owner as xs:string, $group as xs:string, $perms as xs:integer ) {
  let $data := request:get-uploaded-file-data('xt-photo-file')
  return
    if (not($data instance of xs:base64Binary)) then
      osimg:gen-error('Le fichier téléchargé est invalide')
    else
      (: check photo binary stream has compatible MIME-TYPE :)
      let $filename := request:get-uploaded-file-name('xt-photo-file')
      let $ext:= osimg:get-extension($filename)
      let $mime-check := osimg:check-extension($ext)
      return
        if ( $mime-check != 'ok' ) then
          osimg:gen-error($mime-check)
        else
          (: create image collection if it does not exist yet :)
          let $col-uri := osimg:create-collection-lazy(oppidum:path-to-ref-col(), $owner, $group, $perms)
          return
            if (not(xdb:collection-available($col-uri))) then 
              osimg:gen-error("Erreur sur le serveur: impossible de créer la collection pour recevoir l'image")
            else
              (: check / create last index :)
              let $cur-index := osimg:get-index($col-uri, $owner, $group, $perms)
              return
                if (not($cur-index castable as xs:integer)) then 
                  osimg:gen-error("Erreur sur le serveur: impossible de générer un nom pour stocker l'image")
                else
                  util:exclusive-lock($cur-index, osimg:do-upload($col-uri, $owner, $group, $cur-index, $data, $ext, $perms))
};
