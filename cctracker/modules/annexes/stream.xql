xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Stream the binary reference document

   Limitation:
   - reference resource MUST be terminated with a file extension 
     which is used to create the MIME-TYPE

   February 2014 - European Union Public Licence EUPL
   -------------------------------------- :)

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace mime = "http://platinn.ch/coaching/mime" at "mime.xqm";

let $cmd := request:get-attribute('oppidum.command')
let $dur := request:get-attribute('xquery.cache')
let $cache := if ($dur) then
                if ($dur = 'no-cache') then
                  $dur
                else
                  concat('public, max-age=', $dur)
              else
                'public, max-age=900000'
let $pragma := if ($cache = 'no-cache') then $cache else 'x'
let $file-uri := oppidum:path-to-ref()
let $ext := substring-after($file-uri, '.')
return
 if (util:binary-doc-available($file-uri)) then
   let $file := util:binary-doc($file-uri)
   return (
     response:set-header('Pragma', $pragma),
     response:set-header('Cache-Control', $cache),
     response:set-header('Content-Disposition', concat("attachment; filename=", $cmd/resource/@resource)),
     response:stream-binary($file, mime:get-mime-for-extension($ext))
   )
 else
   ( concat("Erreur 404 : ", $file-uri), response:set-status-code(404) )
