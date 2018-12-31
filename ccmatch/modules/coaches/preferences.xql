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

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:unset-preference( $person as element(), $name as xs:string, $status-label as xs:string, $pref-label as xs:string ) {
  let $prefs := $person/Preferences
  let $legacy := $prefs/*[local-name(.) eq $name]
  return
    if ($legacy) then (
      update delete $legacy,
      ajax:report-success('ACTION-PREFERENCES-SUCCESS', ($status-label, $pref-label), ' ')
      )
    else
      ajax:report-success('INFO', 'No need to change, your choice was already set')
};

(: ======================================================================
   Updates Status facet of person by toggling Available / Unavailable element
   ======================================================================
:)
declare function local:set-preference( $person as element(), $name as xs:string, $status-label as xs:string, $pref-label as xs:string ) {
  let $prefs := $person/Preferences
  let $set := element { $name } { attribute { 'Date'} { current-dateTime() } }
  return
    if ($prefs/*[local-name(.) eq $name]) then
      ajax:report-success('INFO', 'No need to change, your choice was already set')
    else (
      if ($prefs) then
        update insert $set into $prefs
      else
        update insert <Preferences>{ $set }</Preferences> into $person,
      ajax:report-success('ACTION-PREFERENCES-SUCCESS', ($status-label, $pref-label), display:gen-availability-message($person))
      )
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
(: acces control 1 :)
let $user := oppidum:get-current-user()
let $token := tokenize($cmd/@trail, '/')[1]
let $groups := oppidum:get-current-user-groups()
let $person := access:get-person($token, $user, $groups)
return
  if (local-name($person) ne 'error') then
    if ($m eq 'POST') then
      if ($person/Id eq access:get-current-person-id()) then (: access control 2 :)
        let $submitted := oppidum:get-data()
        return
          if (exists($submitted/Coaching)) then
            if ($submitted/Coaching[. = 'on']) then
              local:unset-preference($person, 'NoCoaching', 'available', 'coaching')
            else
              local:set-preference($person, 'NoCoaching', 'not available', 'coaching')
          else if (exists($submitted/Search)) then
            if ($submitted/Search[. = 'on']) then
              local:set-preference($person, 'CoachSearch', 'available', 'search')
            else
              local:unset-preference($person, 'CoachSearch', 'not available', 'search')
          else
          oppidum:throw-error('CUSTOM', 'Unknown preference')
      else
        oppidum:throw-error('FORBIDDEN', ())
    else
      oppidum:throw-error('NOT-FOUND', ())
  else
    $person
