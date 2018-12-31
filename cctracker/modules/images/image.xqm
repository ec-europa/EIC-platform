xquery version "1.0";
(: ------------------------------------------------------------------
   Oppidum module: image helper functions

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Useful methods to manage image collections

   February 2012 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace oppi_images = "http://oppidoc.com/oppidum/images";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";

(: ======================================================================
   Returns a list of all the picture file names referenced in the document
   $doc-uri or in the collection $col-uri, including their potential 
   thumb names. NOTE: the convention is that all the pictures are 
   referenced with Photo or Logo elements.
   ======================================================================
:)
declare function oppi_images:list-image-files( $doc-uri as xs:string?, $col-uri as xs:string? ) as xs:string*
{
  ( 'index.xml',
  if ($doc-uri) then
    for $src in doc($doc-uri)//(Photo[. != ''] | Logo[. != ''])
    return 
      let $name := substring-after(data($src), 'images/')
      return
        ($name, replace($name, '\.', '-thumb.'))
  else if ($col-uri) then
    for $src in collection($col-uri)//(Photo[. != ''] | Logo[. != ''])
    return 
      let $name := substring-after(data($src), 'images/')
      return
        ($name, replace($name, '\.', '-thumb.'))
  else 
    ()
  )
};

(: ======================================================================
   Removes all the unused picture files stored in collection $img-col-uri
   which are referenced either from the document $doc-uri or from resources
   inside the collection $col-uri. ONLY $doc-uri OR $col-uri should be set.
   ======================================================================
:)
declare function oppi_images:cleanup-dandling-images(
  $doc-uri as xs:string?,
  $col-uri as xs:string?,
  $img-col-uri as xs:string ) 
{
  (
  oppidum:debug(('cleanup-dandling-images for', if ($doc-uri) then $doc-uri else $col-uri, ' from ', $img-col-uri)),
  if (xdb:collection-available($img-col-uri)) then
    let $images := fn:distinct-values(oppi_images:list-image-files($doc-uri, $col-uri))
    for $file in xdb:get-child-resources($img-col-uri)
    return
      if  (not($file = $images)) then (
        oppidum:debug(('cleaning', $file)),
        xdb:remove($img-col-uri, $file)
        )
      else () 
  else ()
  )
};
