xquery version "1.0";
(: ------------------------------------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Stub file to annex.xqm module to manage annex file upload with AXEL 'file' plugin Ajax protocol.
   Annexes are uploaded documents attached to a collection.

   Currently this file is not used, instead annex upload is handled by an appendices.xql
   controller which calls annex.xqm module and in addition manages uploaded file meta-data directly
   within the XML document hosting the annex.

   See also mime.xqm for the definition of accepted mime types

   September 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace annex = "http://www.oppidoc.com/ns/annex" at "annex.xqm";

declare option exist:serialize "method=text media-type=text/plain indent=no";

(:::::::::::::  BODY  ::::::::::::::)

let $cmd := oppidum:get-command()
return
  if (request:get-parameter('xt-file-preflight', ())) then
    annex:submit-preflight($cmd)
  else
    annex:submit-file($cmd)
    
