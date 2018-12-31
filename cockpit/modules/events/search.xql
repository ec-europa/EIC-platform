xquery version "1.0";
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
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Generates an in-memory cache to speed up page rendering by reducing
   the amount of database lookup operations
   ======================================================================
:)
(:declare function local:gen-cache() as map() {
  map:put(
    display:gen-map-for('Functions', 'Brief', 'en'), (: FunctionsBrief :)
    'project-officers',
    custom:gen-project-officers-map()
  )
};:)

let $payload := oppidum:get-data()
let $staff := oppidum:get-current-user-groups() = ('admin-system', 'project-officer', 'developer')
let $crawler := not($staff) and oppidum:get-current-user-groups() = ('events-manager')
let $profile := if ($crawler) then user:get-user-profile() else ()
let $programs := if ($crawler) then $profile//Role[FunctionRef eq '5']/ProgramId else ()
(: narrows down search to compatible programs for events mangagers :)
return
  <Response Programs="{ $programs }">
    <Table>events</Table>
    { search:fetch-events($payload, $programs, ()) }
  </Response>
