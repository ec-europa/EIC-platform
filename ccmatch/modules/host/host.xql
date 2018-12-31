xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller for Host organization account

   Currently only reads Host account data

   TODO:
   - write controller
   - host creation (multi-hosting ?)

   June 2016 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $host-ref := tokenize($cmd/@trail, '/')[2]
let $host := fn:collection($globals:hosts-uri)//Host[Id eq $host-ref]
return
  (: TODO: add Name :)
  if ($host) then
    <Profile>
      <HostAccount>
        { $host/* }
      </HostAccount>
    </Profile>
  else 
    oppidum:throw-error('URI-NOT-FOUND', ())
