xquery version "1.0";
(: ------------------------------------------------------------------
   EIC Coaching home view

   Creator: Stéphane Sire <s.sire@opppidoc.fr>

   Shared methods to access user's submission entity

   June 2013 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace submission = "http://www.oppidoc.fr/oppidum/submission";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";

declare variable $submission:empty-req := <Request/>;

(: ======================================================================
   Returns the saved search request from the user's profile if it exists
   or a conventional empty request otherwise
   $name is the name of the element storing the request in UserProfile
   ======================================================================
:)
declare function submission:get-default-request ( $name as xs:string ) as element() {
  let $profile := access:get-current-person-profile()
  let $found := $profile/*[name(.) = $name]
  return
    if ($found) then
      $found
    else
      $submission:empty-req
};
