xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@opppidoc.fr>

   Match criteria search service integration

   September 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace httpclient = "http://exist-db.org/xquery/httpclient";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace analytics = "http://oppidoc.com/ns/analytics" at "../../../excm/modules/analytics/analytics.xqm";

declare option exist:serialize "method=html media-type=text/html";

declare function local:rpc( $service as xs:string, $payload as element() ) {
  let $result :=
    services:post-to-service(
      'ccmatch-public', $service,
      $payload,
      ("200")
      )
  return
    if (local-name($result) ne 'error') then
      <div>{ $result//httpclient:body/* }</div>
    else
      $result
};

(: ======================================================================
   Generates service XML payload request for a coach summary
   ====================================================================== 
:)
declare function local:gen-summary-request( $id as xs:string ) {
  <Summary>
    { services:get-key-for('ccmatch-public', 'ccmatch.summary') }
    <CoachRef>{ $id }</CoachRef>
  </Summary>
};

(: ======================================================================
   Generates service XML payload request for a coach inspect
   ====================================================================== 
:)
declare function local:gen-inspect-request( $id as xs:string ) {
  <Inspect>
    { services:get-key-for('ccmatch-public', 'ccmatch.inspect') }
    <CoachRef>{ $id }</CoachRef>
  </Inspect>
};

(: ======================================================================
   Forwards Nonce request to CoachMatch and returns Resource link 
   forged with returned Nonce
   ====================================================================== 
:)
declare function local:query-nonce( ) {
  let $data := oppidum:get-data()
  let $res := services:post-to-service('ccmatch-public', 'ccmatch.nonce', $data, ("200"))
  return
    if (local-name($res) ne 'error') then
      <Nonce><Link>{ services:get-hook-address('ccmatch.links', 'ccmatch.coaches') }/{$data/Resource/text()}?auth={$res//httpclient:body/Nonce/text()}</Link></Nonce>
    else
      $res
};

let $cmd := oppidum:get-command()
let $uuid := request:get-parameter('uuid', ())
return
  if ($cmd/@action eq 'inspect') then
    let $ref := oppidum:get-data()/CoachRef (: TODO: validate ? :)
    return (
      analytics:record-event($uuid, 'Inspect', $ref),
      local:rpc('ccmatch.inspect', local:gen-inspect-request($ref))
      )
  else if ($cmd/@action eq 'nonce') then (
    util:declare-option("exist:serialize", "method=xml media-type=application/xml encoding=utf-8"),
    local:query-nonce()
    )
  else
    local:rpc('ccmatch.summary', local:gen-summary-request($cmd/resource/@name))
