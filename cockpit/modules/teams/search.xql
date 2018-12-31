xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Team / Member search request

   Returns Ajax JSON Table protocol
   
   May 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace search = "http://oppidoc.com/ns/application/search" at "search.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Generates an in-memory cache to speed up page rendering by reducing
   the amount of database lookup operations
   ======================================================================
:)
declare function local:gen-cache() as map() {
  map:put(
    map:put(
      display:gen-map-for('Functions', 'Brief', 'en'), (: FunctionsBrief :)
      'project-officers',
      custom:gen-project-officers-map()
    ),
    'enterprise-scope',
    form:get-normative-selector-for('Functions')/Option[@Scope = "enterprise"]/Value/text()
  )
};

let $payload := oppidum:get-data()
let $target := head(($payload/AccreditationTypeRef, '1')) (: default to Delegate members :)
(: decode table name for JSON response from AccreditationTypes selector Table annotation :)
let $table := form:get-normative-selector-for('AccreditationTypes')/Option[Value eq $target]/Table/text()
return
  <Response>
    <Table>{ $table }</Table>
    {
    switch ($target)
       case '1' return search:fetch-delegates($payload, local:gen-cache())
       (: DEPRECATED - case '2' return search:fetch-investors($payload, local:gen-cache()):)
       case '3' return search:fetch-tokens($payload, local:gen-cache())
       case '4' return search:fetch-unaffiliated($payload, local:gen-cache())
       case '5' return search:fetch-entries($payload)
       default return ()
    }
  </Response>
