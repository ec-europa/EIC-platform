xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Basic service to test access control rules, example :
   /test/access?case=189&activity=2&r=Assignment&a=delete

   June 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

(:declare default element namespace "http://www.w3.org/1999/xhtml";:)

declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xt = "http://ns.inria.org/xtiger";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../lib/display.xqm";

declare function local:gen-role-description( $role as xs:string ) {
  let $role := fn:doc($globals:application-uri)//Description/Role[Name eq $role]
  return $role/Legend/text()
};

declare function local:gen-role-table( $workflow as xs:string, $steps as xs:integer* ) {
<table>
  <thead>
    <th>Status</th>
    {
      for $i in $steps
      let $name := display:gen-workflow-status-name($workflow, string($i), 'en')
      return
        <td>{ $name }</td>
    }
  </thead>
  <tbody>
    {
    for $i in $steps
    let $name := display:gen-workflow-status-name($workflow, string($i), 'en')
    return  
      <tr>
        <td>{ $name }</td>
        {
        for $j in $steps
        let $transition := fn:doc($globals:application-uri)//Workflow[@Id eq $workflow]//Transition[@From eq string($i)][@To eq string($j)]
        return 
          <td>
            { 
            if ($transition) then (
              <p class="role">{string-join($transition/Meet/text(), " ")}</p>,
              <p class="recipients">{string-join($transition/Recipients/text(), " ")}</p>
              )
            else 
              '-'
            }
          </td>
        }
      </tr>
    }
  </tbody>
</table>
};

let $lang := 'en'
let $action := request:get-parameter('a', 'update')
let $root := request:get-parameter('r', 'Information')
let $case-no := request:get-parameter('case', ())
let $activity-no :=  request:get-parameter('activity', ())
let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
let $activity := if ($activity-no) then $case/Activities/Activity[No = $activity-no] else ()
let $verb := if ($action eq 'read' ) then 'GET' else 'POST'
(: --- stage check --- :)
let $person := access:get-current-person-profile()/ancestor::Person
let $omni-sight := access:check-omniscient-user($person/UserProfile)
return
  <div>
    <style>
    table {{
      border-collapse: collapse;
      font-size: 16px;
      margin-bottom: 10px;
    }}
    td {{
      padding: 0 4px;
      vertical-align: top;
      border: solid 1px #DDDDDD;
    }}
    p.role {{
      color: green;
    }}
    p.recipients {{
      color: blue;
      text-align: right;
    }}
    </style>
    <div class="row-fluid" style="margin-bottom: 2em">
      <h1>Case Tracker Access Rules Test</h1>
      <p>Use this page to test the workflow access control engine </p>
    </div>
    {
    if ($case-no) then
      (
      if ($activity) then (
        <p>Querying action "{$action}" on root "{$root}" on case <a href="../cases/{$case-no}" target="_blank">{$case-no} - {$case/Information/Title/text()}</a> for activity { $activity-no } for user { access:get-current-person-id () } :</p>,
        <p>Pre-check ({ $verb }, { $action }, { $root }) : { access:pre-check-activity($case, $activity, $verb, $action, $root) }</p>,
        <p>Check = { access:check-user-can($action, $root, $case, $activity) }</p>
        )
      else (
        <p>Checking action "{$action}" on root "{$root}" on case <a href="../cases/{$case-no}" target="_blank">{$case-no} - {$case/Information/Title/text()}</a> for user { access:get-current-person-id () } :</p>,
        <p>Pre-check ({ $verb }) : { access:pre-check-case($case, $verb, $action, $root) }</p>,
        <p>Check = { access:check-user-can($action, $root, $case) }</p>,
        if ($activity-no) then <p style="color:red">Activity no { $activity-no } not found</p> else ()
        ),
      <p>Current case status : { number($case/StatusHistory/CurrentStatusRef) }</p>,
      if ($activity)  then
        <p>Current activity status : { number($activity/StatusHistory/CurrentStatusRef) }</p>
      else
        (),
      <p>Omni-sight user : {$omni-sight }</p>
      )
    else (
      <p>access:check-omnipotent-user-for('search', 'Coach') : { access:check-omnipotent-user-for('search', 'Coach') }</p>,
      <p>Groups : { oppidum:get-current-user-groups() }</p>,
      <p>Usage: parameters ?case=case-no&amp;activity=activity-no&amp;r=root&amp;a=action</p>
      )
    }
  </div>
