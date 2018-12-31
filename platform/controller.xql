xquery version "1.0";
(: ------------------------------------------------------------------
   Platform : SMEIMKT environment post-deployment scripts

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   September 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace gen = "http://oppidoc.com/oppidum/generator" at "../oppidum/lib/pipeline.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../oppidum/lib/util.xqm";

(: ======================================================================
                  Site default access rights
   ====================================================================== :)
declare variable $access := <access>
  <rule action="GET POST DELETE" role="u:admin" message="system administrator"/>
</access>;

(: ======================================================================
                      Site default actions
   ====================================================================== :)
declare variable $actions := <actions></actions>;

(: ======================================================================
   Multilingual support to be migrated inside Oppidum
   ======================================================================
:)
declare function local:localize( $path as xs:string, $languages as xs:string, $deflang as xs:string ) as xs:string {
  let $options := tokenize($languages," ")
  let $code := if (matches($path,"^/\w\w/?$|^/\w\w/")) then substring($path, 2, 2) else ()
  return
    if ($code = $options) then (: valid 2-letters language code in URL path, return it :)
      $code
    else (: no language code in URL path, default language :)
      $deflang
};

(: NOTE : call oppidum:process with false() to disable ?debug=true mode :)
let $mapping := fn:doc('/db/www/platform/config/mapping.xml')/site
let $lang := local:localize($exist:path, string($mapping/@languages), string($mapping/@default))
return gen:process($exist:root, $exist:prefix, $exist:controller, $exist:path, $lang, true(), $access, $actions, $mapping)
