xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors: 
   - Stéphane Sire <s.sire@oppidoc.fr>

   Project Officers synchronization with Case Tracker

   May 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../../xcm/lib/database.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Invokes Case Tracker service to retrieve project officers
   Creates corresponding officers inside persons collection and inside Members
   container inside EASME pre-defined company (Id: 1)
   FIXME: EASME hard-coded with Id 1 must be bootstrapped (see data/enteprises/1.xml)
   FIXME: actually case tracker export service is a quick hack on top 
   of the coaches export, the tag names are still Coaches / Coach...
   ====================================================================== 
:)
declare function local:import( $db-uri as xs:string ) as element() {
  let $payload :=  <Export Format="profile"><Function>project-officer</Function></Export>
  let $officers := services:post-to-service('cctracker', 'cctracker.coaches', $payload, "200")
  let $easme := fn:collection($globals:enterprises-uri)//Enterprise[Id eq '1']
  return
    if (local-name($officers) ne 'error') then
      <Imported>
      {
      (: TODO: find <missing> ? :)
      for $officer in $officers//Coach (: FIXME: tag name from WS :)
      let $name := concat($officer/Name/FirstName, ' ', $officer/Name/LastName)
      let $key := $officer/Remote[@Name eq 'ECAS']
      (: sanity check - TODO: normalize Email :)
      let $exist-member := exists($easme//Member[Information/Contacts/Email eq $officer/Contacts/Email])
      let $exist-remote := $key and fn:collection($globals:persons-uri)//UserProfile[Remote[@Name eq 'ECAS'] = $key]
      return
        if ($exist-member and $exist-remote) then
          (: TODO: synchronize data ? :)
          <ok key="teams/1" reason="no need to import, already registered in the application">{ $name }</ok>
        else if (not($exist-member) and $exist-remote) then
          (: TODO: fix it ? :)
          <aborted reason="the ECAS remote key already exists (with Id { fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq 'ECAS'] = $key]/Id/text() }) but no record found in EASME team, tell an administrator">{ $name }</aborted>
        else if (not($exist-remote) and $exist-member) then 
          (: TODO: fix it ? :)
          <aborted key="teams/1" reason="the record exists in EASME team but no ECAS remote key, tell an administrator">{ $name }</aborted>
        else
          (: TODO: handle importation w/o Remote => copy Email to UserProfile ? :)
          let $res := template:create-resource('project-officer', $easme, (), $officer, '-1')
          return
            if (local-name($res) ne 'error') then
              <created key="teams/1" reason="project officer recorded into the application">{ $name }</created>
            else
              <failed key="teams/1" reason="{ string($res) }">{ $name }</failed>
      }
      </Imported>
    else
      oppidum:throw-error('CUSTOM', $officers/message/text())
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
        <Id>{ string($item/@key) }</Id>
        <Outcome>{ local-name($item) }</Outcome>
        <Notes>
          {
            string-join(
              ($item/@path, $item/@error, $item/@reason),
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
let $cmd := oppidum:get-command()
return
  if ($m eq 'POST') then (: Ajax JSON table protocol :)
    let $access := access:get-entity-permissions('import', 'PO', <Unused/>)
    return
      if (local-name($access) eq 'allow') then
        let $res := local:import($cmd/@db)
        return
          if (local-name($res) ne 'error') then (
            util:declare-option("exist:serialize", "method=json media-type=application/json"),
            local:ajaxify('run', $res, 'officers'),
            (: errors already reported in table rows :)
            response:set-status-code(200)
            )
          else
            $res
      else
        $access
  else
    oppidum:throw-error('URI-NOT-FOUND', ())
