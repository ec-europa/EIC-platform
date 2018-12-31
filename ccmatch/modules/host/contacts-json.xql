xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Updates a coach preferences

   December 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=json media-type=application/json";

declare function local:read-contacts-for-host( $host-ref as xs:string ) as element()*
{
  let $host := fn:collection($globals:hosts-uri)//Host[Id = $host-ref]
  return
  <Root>
    <Table>host-coach-contact</Table>
    {
      for $contact in $host//Contact
      let $p := fn:collection($globals:persons-uri)//Person[Id/text() = $contact/PersonRef/text()]
      return
        <Users>
        {
          $p/Id,
          $p/Information/Name
        }
        </Users>
    }
  </Root>
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $host-ref := tokenize($cmd/@trail, '/')[2]
return
  if (fn:collection($globals:global-info-uri)//Selector[@Name = "Hosts"]/Option[Id eq $host-ref]) then 
    (: acces control 1 :)
    let $user := oppidum:get-current-user()
    let $groups := oppidum:get-current-user-groups()
    let $profile := access:get-current-person-profile()
    return
      (: access control: check user is Host manager for host :)
      if ($profile//Role[FunctionRef eq '2'][HostRef eq $host-ref] or ($groups = ('admin-system'))) then 
        local:read-contacts-for-host($host-ref)
      else
        oppidum:throw-error('FORBIDDEN', ())
  else 
    oppidum:throw-error('URI-NOT-FOUND', ())
  


