xquery version "3.1";
(: --------------------------------------
   DEPRECATED: moved to EXCM
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";

declare option exist:serialize "method=xml media-type=text/xml";


declare function local:process-filter( $history as element(), $target as xs:string, $action as xs:string, $value as xs:string, $count as xs:string) {
  update insert element { $target } { attribute MatchCount { $count }, $value } into $history/Events
};


let $cmd := oppidum:get-command()
let $uuid := $cmd/resource/@name
let $action := request:get-parameter('action', 'unknown')
let $target := request:get-parameter('target', 'notarget')
let $value := request:get-parameter('value', 'novalue')
let $count := request:get-parameter('count', 'nocount')
let $m := request:get-method()
let $user := oppidum:get-current-user()
let $history := collection($globals:analytics-uri)//History[Request/UUID = $uuid][not(@Done)]
return
  let $record :=
    if ($history/Events) then
      if ($action eq 'filter') then
        local:process-filter( $history, $target, $action, $value, $count )
      else
        update insert element { $target } { $action } into $history/Events
    else
      ()
  return <Done/>