xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Returns JSON data model to construct tables for coach management 
   for a given host (e.g. /hosts/1/acceptances.json?key=1)

   Then data is a list of coach in a given acceptance status
   Uses a key request parameter to select the table

   June 2016 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

declare option exist:serialize "method=json media-type=application/json";

declare function local:read-acceptances-for-host( $host-ref as xs:string, $key as xs:string*, $a as xs:string, $nb as xs:string, $ln as xs:string?) as element()* {
  <Root>
    <Table>
    {
      if ($key = '1') then 'host-applicant'
      else if ($key = '4') then 'host-accepted'
      else 'host-deleted'
    }
    </Table>
    {
      let $all :=
        for $p in fn:collection($globals:persons-uri)//Person[string(Hosts/Host/@For) = $host-ref][Hosts//AccreditationRef/text() = $key]
        let $host := $p//Host[@For = $host-ref]
        where (not(empty($ln)) and contains(upper-case($p/Information/Name/LastName), upper-case($ln))) or empty($ln)
        order by $host/AccreditationRef/@Date descending
        return $p
      for $p in if ($key = '1') then $all else subsequence($all, number($a), number($nb))
      return
        <Users>
          { person:gen-coach-sample-for-mgt-table($p, $host-ref) }
        </Users>
    }
  </Root>
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $host-ref := string($cmd/resource/@name)
return
  if (fn:collection($globals:global-info-uri)//Selector[@Name = "Hosts"]/Option[Id eq $host-ref]) then 
    let $user := oppidum:get-current-user()
    let $groups := oppidum:get-current-user-groups()
    let $profile := access:get-current-person-profile()
    let $key := request:get-parameter('key',('2','3'))
    let $a := request:get-parameter('a','1')
    let $nb := request:get-parameter('nb','50')
    let $ln := request:get-parameter('ln',())
    return
      (: access control: check user is Host manager for host :)
      if ($profile//Role[FunctionRef eq '2'][HostRef eq $host-ref] or ($groups = ('admin-system'))) then 
        local:read-acceptances-for-host($host-ref, $key, $a, $nb, $ln)
      else
        oppidum:throw-error('FORBIDDEN', ())
  else 
    oppidum:throw-error('URI-NOT-FOUND', ())
