xquery version "1.0";
(: --------------------------------------

   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../../xcm/modules/users/account.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns true if the case is more recent than the subset 
   ====================================================================== 
:)
declare function local:expired( $cached as xs:string, $extract as element() ) as xs:boolean {
  some $ts in $extract//@LastModification satisfies ($cached < $ts)
};

(: ======================================================================
   Returns Case sample
   ======================================================================
:)
declare function local:gen-event-sample( $event as element() ) as element() {
  <Event ProjectId="{ if ($event/Data/Application//Acronym) then $event/Data/Application//Acronym else $event/Data/Application//SMEIgrantagreementnumber }">
    {
    $event/(Id | StatusHistory)
    }
  </Event>
};

(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('cockpit', 'cockpit.events', $submitted)
return
  system:as-user(account:get-secret-user(), account:get-secret-password(),
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    let $id := if ($search/@Id) then string($search/@Id) else ()
    let $force := if ($search/Call/@Force ne '') then tokenize($search/Call/@Force, ',') else ()
    return
      let $first :=
        <Events>
          {
          for $event in fn:collection($globals:enterprises-uri)//Enterprise/Events/Event
          let $diff := local:expired($search/@LastUpdate, $event)
          let $acro := $event/Data/Application//(Acronym | SMEIgrantagreementnumber)
          where ((empty($id) or $acro = $id)
            and (empty($search/@LastUpdate) or $diff)) or ($force = $acro)
          return local:gen-event-sample($event)
          }
        </Events>
      return
        <Events Id="{$id}">
          <Metadata>
          {
          for $def in fn:collection($globals:events-uri)//Event[Id = $first//Event/Id]
          return <Event>{ $def/@*, $def/(Id | Template | Programme | Information) }</Event>
          }
          </Metadata>

          { $first/* }
        </Events>
  else
    $errors)
