xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors: 
   - Stéphane Sire <s.sire@oppidoc.fr>

   Calls Case Tracker enterprises export service to create :
   - enterprises
   - projects (one enterprise may have several projects)

   Use with ?letter={letter} for restricting to a letter prefix

   May 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../../xcm/lib/database.xqm";
import module namespace cache = "http://oppidoc.com/ns/xcm/cache" at "../../../xcm/lib/cache.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:create-project (
  $legacy as element(),
  $enterprise as element(),
  $mode as xs:string
  ) as element()?
{
  if ($mode eq 'run') then 
    let $res := template:do-create-resource('project', $legacy, (), $enterprise, '-1')
    return
      if (local-name($res) eq 'success') then
        <created key="{ $legacy/Id }" path="project { $enterprise/@ProjectId }">{ $enterprise/Information/Name/text() }</created>
      else
        <failed reason="{ string($res) }" path="project { $enterprise/@ProjectId }">{ $enterprise/Information/Name/text() }</failed>
  else (: dry run - simulation :)
    <created key="{ $legacy/Id }" path="project { $enterprise/@ProjectId }">{ $enterprise/Information/Name/text() }</created>
};

(: ======================================================================
   Generates new index key and creates enterprise in database
   ====================================================================== 
:)
declare function local:create-enterprise (
  $enterprise as element(),
  $mode as xs:string
  ) as element()?
{
  if ($mode eq 'run') then
    (: FIXME: bloquer invalidate ? :)
    let $res := template:do-create-resource('enterprise', (), (), $enterprise, '-1')
    return
      if (local-name($res) eq 'success') then
        <created key="{string($res/@key)}" path="{ $res }">{ $enterprise/Information/Name/text()  }</created>
      else
        <failed reason="{ string($res) }">{ $enterprise/Information/Name/text() }</failed>
  else (: dry run - simulation :)
    let $new-key := database:make-new-key-for(oppidum:get-command()/@db, 'enterprise')
    let $col-uri := database:gen-collection-for-key(oppidum:get-command()/@db, 'enterprise', $new-key)
    return
      if (local-name($col-uri) eq 'success') then
        <created key="{ $new-key }" path="{ concat($col-uri, '/', $new-key) }">{ $enterprise/Information/Name/text() }</created>
      else
        <failed reason="{ string($col-uri) }">{ $enterprise/Information/Name/text() }</failed>
};

(: ======================================================================
   Invokes Case Tracker service to retrieve companies by Call and Letter
   Creates corresponding companies inside cockpit database
   ====================================================================== 
:)
declare function local:import( $call as xs:string?, $letter as xs:string?, $mode as xs:string ) as element() {
  let $payload :=
    <Export>
      { 
      if ($letter) then attribute { 'Letter' } { $letter } else (),
      <Call><Date>{ $call }</Date></Call>
      }
    </Export>
  let $enterprises := services:post-to-service('cctracker', 'cctracker.enterprises', $payload, "200")
  return
    if (local-name($enterprises) ne 'error') then
      <Imported Call="{ $call }">
      {
      for $enterprise in $enterprises//Enterprises/Enterprise
      let $legacy := fn:collection($globals:enterprises-uri)//Enterprise[@EnterpriseId eq $enterprise/@EnterpriseId]
      return
        if (exists($legacy)) then
          if ($legacy//Project[ProjectId eq $enterprise/@ProjectId]) then
            <exists key="{$legacy/Id}">
              { $enterprise/(@EnterpriseId, Information/Name/text()) }
            </exists>
          else
            local:create-project($legacy, $enterprise, $mode)
        else
          local:create-enterprise($enterprise, $mode),
      if ($mode eq 'run') then (
        cache:invalidate('enterprise', 'en'),
        cache:invalidate('town', 'en')
        )
      else
        ()
      }
      </Imported>
    else
      oppidum:throw-error('CUSTOM', $enterprises/message/text())  
};

(: ======================================================================
   Turns response into Ajax JSON table protocol format
   See also enterprises-ui.xsl, search.js
   ====================================================================== 
:)
declare function local:ajaxify( $mode as xs:string, $res as element(), $table as xs:string ) as element() {
  <Response>
    <Table>{ $table }</Table>
    {
    for $item in $res/*
    return
      <Users>
        <Name>{ string($item) }</Name>
        { if (($mode eq 'run' or local-name($item) eq 'exists' or starts-with($item/@path, 'project')) and $item/@key) then <Id>{ string($item/@key) }</Id> else () }
        <Outcome>{ local-name($item) }</Outcome>
        <Notes>
          {
            string-join(
              ($item/@path, $item/@reason),
              ', '
              )
          }
        </Notes>
      </Users>
    }
  </Response>
};


(: MAIN ENTRY POINT :)
let $m := request:get-method()
return
  if ($m eq 'POST') then (: Ajax JSON table protocol :)
    let $submitted := oppidum:get-data()
    let $res := local:import($submitted/Call, $submitted/Letter, $submitted/Mode)
    return
      if (local-name($res) ne 'error') then (
        util:declare-option("exist:serialize", "method=json media-type=application/json"),
        local:ajaxify($submitted/Mode, $res, 'imports'),
        (: errors already reported in table rows :)
        response:set-status-code(200)
        )
      else
        $res
  else
    let $call := request:get-parameter('call', ())
    let $letter := request:get-parameter('letter', ())
    let $mode := request:get-parameter('mode', 'dry')
    return
      local:import($call, $letter, $mode)


