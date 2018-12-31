xquery version "1.0";
(: ------------------------------------------------------------------
   Oppidoc Supergrid application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   May 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace sg = "http://coaching.ch/ns/supergrid";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace file="http://exist-db.org/xquery/file";
declare namespace transform = "http://exist-db.org/xquery/transform";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";

(: ======================================================================
   Executes supergrid transformation on a template specification
   Precondition: - login as "admin" (DBA role)
   ======================================================================
:)
declare function sg:gen-and-save-form( $name as xs:string, $base-url as xs:string ) {
  let $col-uri := concat('/db/www/', $globals:app-collection, '/mesh')
  let $filename := concat($name, '.xhtml')
  let $sg := concat('file://', system:get-exist-home(), '/webapp/', $globals:app-folder, '/', $globals:app-name, '/modules/formulars/supergrid.xsl')
  let $spec := concat('file://', system:get-exist-home(), '/webapp/', $globals:app-folder, '/', $globals:app-name, '/formulars/', $name, '.xml')
  return 
    if (xdb:get-current-user() = 'admin') then
      if (doc-available($sg)) then
        if (doc-available($spec)) then
          let $data := fn:doc($spec)
          let $params := <parameters>
                           <param name="xslt.base-url" value="{$base-url}"/>
                           <param name="xslt.base-root" value="{system:get-exist-home()}/"/>
                           <param name="xslt.goal" value="save"/>
                           <param name="exist:stop-on-warn" value="yes"/>
                           <param name="exist:stop-on-error" value="yes"/>
                         </parameters>
          return
              let $form := transform:transform($data, $sg, $params)
              let $res := xdb:store($col-uri, $filename, $form)
              return 
                <p>Generated form copied to {$res}</p>
        else
          <p>Could not locate {$spec}</p>
      else
        <p>Could not locate {$sg}</p>
    else
      <p>You must be logged as admin to execute that script (<a href="login?url=forms">login</a>)</p>
};

(: ======================================================================
   Takes a list of formular names (w/o extension) as a + separated list of names
   Generates the formulars using Supergrid transformation and saves them 
   into the '/db/www/ccmatch/mesh' collection
   ======================================================================
:)
declare function sg:gen-and-save-forms( $names as xs:string, $base-url as xs:string ) {
  let $targets := tokenize($names, '\+')
  return
    if (empty($targets)) then
      <p>Missing or wrong gen parameter</p>
    else
      for $t in $targets
      return
        sg:gen-and-save-form($t, $base-url)
};
