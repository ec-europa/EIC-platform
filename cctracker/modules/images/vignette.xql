xquery version "1.0";        
(: --------------------------------------
   Oppidum module: image 

   Author: Stéphane Sire <s.sire@free.fr>

   Serves images from the database. Sets a Cache-Control header.

   TODO:
   - improve Cache-Control (HTTP 1.1) with Expires / Date (HTTP 1.0)
   - (no need for must-revalidate / Last-Modified since images never change)

   March 2012 - European Union Public Licence EUPL
   -------------------------------------- :)

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";

declare option exist:serialize "method=text media-type=text/plain indent=no";

let $cmd := request:get-attribute('oppidum.command')
let $prefix := concat($cmd/resource/@db, '/', $cmd/resource/@collection, '/', $cmd/resource/@resource)
let $thumb-uri := concat($prefix, '-thumb.', $cmd/@format)
let $image-uri := if (util:binary-doc-available($thumb-uri)) 
                  then $thumb-uri 
                  else if (util:binary-doc-available(concat($prefix, '.', $cmd/@format)))
                       then concat($prefix, '.', $cmd/@format)
                       else ()
return
  if ($image-uri)
  then  
    let $image := util:binary-doc($image-uri)
    return (
      response:set-header('Pragma', 'x'),
      response:set-header('Cache-Control', 'public, max-age=900000'),
      response:stream-binary($image, concat('image/', $cmd/@format))
    )
  else
    ( "Erreur 404 (pas d'image)", response:set-status-code(404)  )
