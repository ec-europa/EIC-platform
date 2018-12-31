xquery version "3.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Single feed controller used by console to interact with feeds one by one
   This shows how to interact with the Case Tracker feed API

   July 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace request = "http://exist-db.org/xquery/request";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace feeds = "http://oppidoc.com/ns/feeds" at "feeds.xqm";
import module namespace histories = "http://oppidoc.com/ns/histories" at "../../lib/histories.xqm";

declare option exist:serialize "method=xml media-type=application/xml";
    
declare function local:serialize( $e as element()? ) {
  <pre id="output" xmlns="http://www.w3.org/1999/xhtml">
    { 
    fn:serialize(
      $e,
      <output:serialization-parameters>
        <output:indent value="yes"/>
      </output:serialization-parameters>
    )
    }
  </pre>
};

declare function local:make-feed-request-for-coach( $no as xs:string ) {
  let $algo := request:get-parameter('algo', 'regenerate')
  let $person := fn:collection($globals:persons-uri)/Person[Id eq $no]
  let $index := number($no)
  let $req := feeds:make-feed-requests ('1', $index, $index + 1, $algo)
  return 
    if ($person//Feeds/Feed[@For eq '1']) then 
      $req//Evaluations[last()]
    else
      $req//Evaluations[1]

(: FIXME: 
      factorize test if (count($req/For/*) > 0)
      and return <Request>not available since coach is not activated or has not submitted application </Request>
      :)
      
};

(: ======================================================================
   Return user's archived feed
   ====================================================================== 
:)
declare function local:dump ( $no as xs:string ) {
  let $person := fn:collection($globals:persons-uri)/Person[Id eq $no]
  return
    if ($person) then (
      <Coach>
        {
        $person//Feeds/@Perf,
        concat($person/Information/Name/FirstName, " ", $person/Information/Name/LastName)
        }
      </Coach>,
      $person//Feeds/Feed[@For eq '1']
      )
    else
      ()
};

(: ======================================================================
   Generate, send to Case Tracker and return feed request for a single coach
   ====================================================================== 
:)
declare function local:request ( $no as xs:string ) {
  let $req := local:make-feed-request-for-coach($no)
  return (
    <Request>{ $req }</Request>,
    if (count($req/For/*) > 0) then
      <Response>
        {
          try { 
            services:post-to-service('cctracker', 'cctracker.feeds', $req, ("200")) 
          }
          catch * {
            <error>Caught error {$err:code}: {$err:description}</error>
          }
        }
      </Response>
    else
      <Response>User not a coach, not activated or no application submitted</Response>
    )
};

(: ======================================================================
   Generate, send to Case Tracker and update feed in dry mode 
   for a single coach
   ====================================================================== 
:)
declare function local:dry ( $no as xs:string ) {
  let $req := local:make-feed-request-for-coach($no)
  return
    <Dry>
      { feeds:update-coach-feeds(<Pull>{ $req }</Pull>, '1', true()) }
    </Dry>
};

(: ======================================================================
   Generate, send to Case Tracker and update feed for a single coach
   ====================================================================== 
:)
declare function local:run ( $no as xs:string ) {
  let $req := local:make-feed-request-for-coach($no)
  return
    <Run>
      { feeds:update-coach-feeds(<Pull>{ $req }</Pull>, '1', false()) }  
    </Run>
};

let $cmd := oppidum:get-command()
let $action := request:get-parameter('action', 'dump')
let $no := $cmd/resource/@name
return
local:serialize(
  <Request For="{ $no }">
    {
    switch ($action)
    case 'dump' return local:dump($no)
    case 'request' return local:request($no)
    case 'dry' return local:dry($no)
    case 'run' return local:run($no)
    default return "unsupported action"
    }
  </Request>
  )
