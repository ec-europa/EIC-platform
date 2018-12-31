xquery version "1.0";
(: --------------------------------------
   Experimental localization

   Author: Stéphane Sire <s.sire@oppidoc.fr>

   Utility script to save localization messages

   September 2013 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=application/xml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

let $data := oppidum:get-data()
let $dico := fn:doc('/db/www/cctracker/config/dictionary.xml')/site:Dictionary/site:Translations[@lang = $data/@lang]
return
  if ($dico) then (
    for $t in $data/Translation
    let $dk := $dico/site:Translation[@key = $t/@key]
    return
      if ($dk) then
        update value $dk with $t/text()
      else
        update insert <Translation xmlns="http://oppidoc.com/oppidum/site" key="{$t/@key}">{$t/text()}</Translation> into $dico,
    <message>language dictionary updated with success</message>
    )
  else (
    response:set-status-code(500),
    <message>{concat("language dictionary '", string($data/@lang), "' not found")}</message>
  )
