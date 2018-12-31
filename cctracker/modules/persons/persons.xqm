xquery version "1.0";
(: --------------------------------------
   Case Tracker application

   Creation: Franck Leplé <franck.leple@amplexor.com> 

   Persons library

   November 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace persons = "http://oppidoc.com/ns/cctracker/persons";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace database = "http://oppidoc.com/ns/database" at "../../../excm/lib/database.xqm";

(: ======================================================================
   Create a person in the persons bucketised collection 
   Params:
    - $person: XML element with person content
    - $newkey: new person id
   ======================================================================
:)
declare function persons:create-person-in-collection($person as element(), $newkey as xs:string) {
    let $col := misc:gen-collection-name-for($newkey)
    let $fn := concat($newkey, '.xml')
    let $col-uri := database:create-collection-lazy-for($globals:persons-uri, $col, 'person')
    let $stored-path := xdb:store($col-uri, $fn, $person)
    return 
    (
      if (not($stored-path eq ())) then
        database:apply-policy-for($col-uri, $fn, 'Person')
      else
        (),
      $stored-path
    )[last()]
};

