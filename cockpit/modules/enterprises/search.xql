xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Enterprise search request

   Returns Ajax JSON Table protocol
   
   April 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace search = "http://oppidoc.com/ns/application/search" at "search.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Generates an in-memory cache to speed up page rendering by reducing
   the amount of database lookup operations
   ======================================================================
:)
declare function local:gen-cache() as map() {
  display:gen-map-for(('DomainActivities', 'Sizes', 'TargetedMarkets'), 'en')
};

let $payload := oppidum:get-data()
return
  <Response>
    <Table>companies</Table>
    { search:fetch-enterprises($payload, local:gen-cache()) }
  </Response>
