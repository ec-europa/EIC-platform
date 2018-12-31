xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Searches users for user management

   September 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Returns the list of user with their account information matching submitted criteria 
   ======================================================================
:)
declare function local:search-by-criteria( $submitted as element() ) as element()* {
  let $role := $submitted//RoleRef/text()
  let $country := $submitted//Country/text()
  let $person := $submitted//PersonRef/text()
  return
    for $p in fn:collection($globals:persons-uri)//Person
    let $name := $p/Information/Name
    where (empty($person) or ($p/Id = $person))
      and (empty($country) or ($p/Information/Address/Country = $country))
      and (empty($role) or ($p/UserProfile//FunctionRef = $role))
    order by lower-case($name/LastName), lower-case($name/FirstName)
    return
      person:gen-user-sample-for-mgt-table($p, ())
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
(:let $lang := string($cmd/@lang):)
return
  if ($m = 'POST') then
    let $data := oppidum:get-data() (: TODO: validate $data :)
    return
      <SearchResults Table="user">
        { local:search-by-criteria($data) }
      </SearchResults>
  else
    oppidum:throw-error('NOT-IMPLEMENTED', ())
