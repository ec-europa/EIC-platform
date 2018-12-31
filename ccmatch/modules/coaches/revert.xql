xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Revert a coach availability for coaching

   DEPRECATED : not used any more !

   December 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Updates Status facet of person by toggling Available / Unavailable element
   ====================================================================== 
:)
declare function local:update-availability( $person as element() ) {
  let $legacy := $person/Status
  return (
    if ($legacy) then
      if ($legacy/Available) then
        update replace $legacy with <Unavailable Date="{current-dateTime()}"/>
      else if ($legacy/Unavailable) then
        update delete $legacy/Unavailable
      else (: 1st time : set to unavailable :)
        update insert <Unavailable Date="{current-dateTime()}"/> into $legacy
    else (: 1st time : set to unavailable :)
      update insert <Status><Unavailable Date="{current-dateTime()}"/></Status> into $person,
    ajax:report-success('ACTION-REVERT-SUCCESS', (),
      display:gen-availability-message($person))
    )
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
(: acces control 1 :)
let $user := oppidum:get-current-user()
let $id := tokenize($cmd/@trail, '/')[1]
let $groups := oppidum:get-user-groups($user, oppidum:get-current-user-realm())
let $person := access:get-person($id, $user, $groups)
return
  if (local-name($person) ne 'error') then
    if ($m eq 'POST') then
      if ($id eq $user) then (: access control 2 :)
        local:update-availability($person)
      else
        oppidum:throw-error('FORBIDDEN', ())
    else
      oppidum:throw-error('NOT-FOUND', ())
  else
    $person
