xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Returns a user profile model (Information) as XML

   October 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns user profile for viewing / editing in management
   ======================================================================
:)
declare function local:gen-user( $person as element(), $lang as xs:string, $goal as xs:string ) as element()* {
  <Profile>{ person:gen-information($person) }</Profile>
};

let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $person-ref := string($cmd/resource/@name)
let $person := fn:collection($globals:persons-uri)//Person[Id eq $person-ref]
return
  if ($person) then
    local:gen-user($person, $lang, request:get-parameter('goal', 'read'))
  else
    oppidum:throw-error("URI-NOT-FOUND", ())
