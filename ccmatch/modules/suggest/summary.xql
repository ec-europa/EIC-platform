xquery version "1.0";

(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Coach summary in suggestion tunnel

   October 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace response="http://exist-db.org/xquery/response";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "match.xqm";

declare function local:gen-coach( $person as element() ) {
  <Coach>
    { $person/Information/Civility }
    <Name>{ display:gen-person-name($person, 'en') } </Name>
    { 
    $person/Information/Contacts/(Email | Phone | Mobile | Skype),
    (: FIXME: CV_Link in import :)
    if ($person/Knowledge/CV_Link) then
      <CV-Link>{ $person/Knowledge/CV_Link/text() }</CV-Link>
    else if ($person/Knowledge/CV-Link) then
      <CV-Link>{ $person/Knowledge/CV-Link/text() }</CV-Link>
    else
      (),
    if ($person/Knowledge//ServiceYearRef[. ne '']) then
      <Experience>
        {
        misc:gen_display_name($person/Knowledge/IndustrialManagement/ServiceYearRef, 'IndustrialManagement'),
        misc:gen_display_name($person/Knowledge/BusinessCoaching/ServiceYearRef, 'BusinessCoaching')
        }
      </Experience>
    else
      (),
    misc:unreference($person/Information/Address)
    }
  </Coach>
};

declare function local:gen-coach-from-host( $id as xs:string?, $user as xs:string, $groups as xs:string*, $host as xs:string ) {
  if ($id) then
    let $person := fn:collection($globals:persons-uri)//Person[Id eq $id]
    return
      if (match:assert-coach($person, $host)) then
        local:gen-coach($person)
      else
        oppidum:throw-error('FORBIDDEN', ())
  else
    oppidum:throw-error('NOT-FOUND', ())
};

let $cmd := request:get-attribute('oppidum.command')
let $m := request:get-method()
let $user := oppidum:get-current-user()
let $groups := oppidum:get-user-groups($user, oppidum:get-current-user-realm())
let $id := $cmd/resource/@name
return
  if ($m eq 'POST') then  (: calling from 3rd party application :)
    let $request := match:get-data($user, 'ccmatch.summary')
    return
      if (local-name($request) ne 'error') then
        let $host := match:get-host($user, $request/Key) (: TODO: 'ccmatch.summary' :)
        return
          if (local-name($host) ne 'error') then
            local:gen-coach-from-host($request/CoachRef, 'guest', (), $host)
          else
            $host
      else
        $request
  else if ($user ne 'guest') then (: authentified user calling from Coach Match search :)
    local:gen-coach-from-host($id, $user, $groups, '0')
  else (: DEPRECATED : weak access control :)
    let $person := access:get-person($id, $user, $groups)
    (: FIXME: access:get-person-from-host($id, HOST KEY ?) :)
    return 
      if (local-name($person) ne 'error') then
        local:gen-coach($person)
      else
        $person
