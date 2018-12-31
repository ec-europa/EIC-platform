xquery version "1.0";
(: --------------------------------------
   Oppidum module: image 

   Author: Stéphane Sire <s.sire@oppidoc.fr>

   Writes a resource to a collection and returns an XML success or error
   message. This design is adapted for simple XML pipeline (no view, no
   epilogue) to be called from an Ajax request.

   That script is to be called if the page uses the image module because
   it cleans up dandling images referenced through a Photo element inside
   the collection that contains the saved resource.

   WARNING: actually that version works for an image collection 
   within the collection that contains the resource, and all the Photo 
   and Logo references are shared among all the resources within 
   the collection

   March 2012 - European Union Public Licence EUPL
   -------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";   
import module namespace xdb = "http://exist-db.org/xquery/xmldb";                    
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace oppistore = "http://oppidoc.com/oppidum/images" at "image.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(:::::::::::::  BODY  ::::::::::::::)
let 
  $cmd := request:get-attribute('oppidum.command'),
  $col-uri := oppidum:path-to-ref-col(),
  $filename := $cmd/resource/@resource
return           
  if (xdb:collection-available($col-uri)) then (: sanity check :)
    let                   
      $data := request:get-data(),
      $stored-path := xdb:store($col-uri, $filename, $data)
    return
      if(not($stored-path eq ())) then (
        oppistore:cleanup-dandling-images((), $col-uri, concat($col-uri, '/images')),
        oppidum:add-message('ACTION-UPDATE-SUCCESS', '', true()),
        response:set-status-code(201),
        response:set-header('Location', concat($cmd/@base-url, $cmd/@trail)), (: redirect info :)
        <success>
          <message>La ressource a été enregistrée</message>
        </success>                      
        )[last()]
      else
        oppidum:throw-error('DB-WRITE-INTERNAL-FAILURE', ())
  else
    oppidum:throw-error('DB-WRITE-NO-COLLECTION', ())
