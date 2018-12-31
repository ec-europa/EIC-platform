xquery version "1.0";
(: ------------------------------------------------------------------
   EASME Case Tracker Application

   Authors: 
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   User account management

   December 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns the list of user with their account information
   ======================================================================
:)
declare function local:gen-remotes-for-viewing() as element()* {
  <Remotes>
  {
  for $p in fn:doc($globals:remotes-uri)/Remotes/Remote
  return
    <Remote>
      {
      <Name>{ $p/Name/text() }</Name>,
      <Key>{ $p/Key/text() }</Key>,
      <Mail>{ $p/Mail/text() }</Mail>,
      $p/Realm,
      <Roles>{ display:gen-roles-for($p/UserProfile/Roles, 'en') }</Roles>
      }
    </Remote>
  }
  </Remotes>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $name := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
return
  if ($m = 'POST') then
    let $data := oppidum:get-data()
    return
      ()
  else (: assumes GET :)
    local:gen-remotes-for-viewing()
