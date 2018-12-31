xquery version "3.0";
(: --------------------------------------
   EXCM - Globals module

   Miscellaneous functions

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>

   Pre-conditions : 'globals' target deployed

   October 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace globals = "http://oppidoc.com/ns/globals";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";

(: this variable MUST be the same as in your application's lib/globals.xqm :)
declare variable $globals:globals-uri := '/db/www/excm/config/globals.xml';

declare function globals:app-name() as xs:string {
  fn:doc($globals:globals-uri)//Global[Key eq 'app-name']/Value
};

declare function globals:app-folder() as xs:string {
  fn:doc($globals:globals-uri)//Global[Key eq 'app-folder']/Value
};

declare function globals:app-collection() as xs:string {
  fn:doc($globals:globals-uri)//Global[Key eq 'app-collection']/Value
};

(: ******************************************************************* :)
(:                                                                     :)
(: Below this point copy content to your application's lib/globals.xqm :)
(:                                                                     :)
(: ******************************************************************* :)

(:~
 : Returns the selector from global information that serves as a reference for
 : a given selector enriched with meta-data.
 : @return The normative Selector element or the empty sequence
 :)
declare function globals:get-normative-selector-for( $name ) as element()? {
  fn:collection(fn:doc($globals:globals-uri)//Global[Key eq 'global-info-uri']/Value)//Description[@Role = 'normative']/Selector[@Name eq $name]
};

declare function globals:doc-available( $name ) {
  fn:doc-available(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};

(: Robust version to support migration from file to collection storage :)
declare function globals:doc( $name ) {
  let $file-uri := fn:doc($globals:globals-uri)//Global[Key eq $name]/Value
  return
    if (ends-with($file-uri, '.xml')) then
      fn:doc($file-uri)
    else
      fn:collection($file-uri)
};

declare function globals:collection-available( $name ) {
  xdb:collection-available(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};

declare function globals:collection-uri( $name ) as xs:string? {
  let $col-uri := fn:doc($globals:globals-uri)//Global[Key eq $name]/Value/text()
  return 
    if (ends-with($col-uri, '/')) then substring($col-uri, 1, string-length($col-uri)-1) else $col-uri
};

declare function globals:collection( $name ) {
  fn:collection(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};
