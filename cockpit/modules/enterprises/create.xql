xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to Create a blank investor company

   Note: could be extended to create other kind of companies
 
   March 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $m := request:get-method()
let $cmd := oppidum:get-command()
return
  if ($m = 'POST') then
    if (access:check-entity-permissions('add', 'Investor')) then
      let $res := template:do-create-resource('investor-company', (), (), <Submitted/>, ())
      return
        if (local-name($res) eq 'success') then
          ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), concat('enterprises/', $res/@key))
        else
          $res
    else
      oppidum:throw-error('FORBIDDEN', ())
  else
    oppidum:throw-error('URI-NOT-SUPPORTED', ())
