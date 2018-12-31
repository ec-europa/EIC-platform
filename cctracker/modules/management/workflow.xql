(:declare default element namespace "http://www.w3.org/1999/xhtml";:)

declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xt = "http://ns.inria.org/xtiger";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare function local:gen-role-description( $role as xs:string ) {
  let $role := fn:doc($globals:application-uri)//Description/Role[Name eq $role]
  return $role/Legend/text()
};

declare function local:gen-block-title( $key as xs:string ) {
  let $t := fn:doc($globals:dico-uri)//site:Translations[@lang = 'en']/site:Translation[@key = $key]
  return if ($t) then $t/text() else $key
};

declare function local:gen-transition-table( $workflow as xs:string, $steps as xs:integer* ) {
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
              <p class="role">{string-join(for $t in $transition/Meet/text() return tokenize($t, " "), ", ")}</p>,
              <p class="recipients">{string-join(for $t in $transition/Recipients/text() return tokenize($t, " "), ", ")}</p>
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

declare function local:gen-document-table( $workflow as xs:string, $steps as xs:integer*, $finals as xs:integer* ) {
<table>
  <thead>
    <th>Block</th>
    <th>Document</th>
    {
      for $i in ($steps, $finals)
      let $name := display:gen-workflow-status-name($workflow, string($i), 'en')
      return
        <th>{ $name }</th>
    }
  </thead>
  <tbody>
    {
    for $doc in fn:doc($globals:application-uri)//Workflow[@Id eq $workflow]/Documents/Document
    (:let $name := display:gen-workflow-status-name($workflow, string($i), 'en'):)
    return
      (
      <tr>
        <td rowspan="{1 + count($doc/Host)}">{local:gen-block-title(concat("workflow.title.", $doc/@Tab))}</td>
        <td>{ string($doc/@Tab) }</td>
        {
        for $i in ($steps, $finals)
        let $visible := string($i) = tokenize(string($doc/@AtStatus), " ")
        let $action := $doc/Action[@Type = ('update','create')][string($i) = tokenize(string($doc/@AtStatus), " ")]
        let $roles := fn:doc($globals:application-uri)//Security//Document[@TabRef = string($doc/@Tab)]/Action[@Type = ('update', 'create')]
        return
          <td>
            {
            if ($i = $finals) then 
              if ($action and $roles) then (
                <p class="role">{string-join($roles/Meet/text(), " ")}</p>
                )
              else
                'o'
            else
              if ($visible) then
                if ($action and $roles) then (
                  <p class="role">{string-join($roles/Meet/text(), " ")}</p>
                  )
                else
                  '-'
              else
                'x'
            }
          </td>
        }
      </tr>,
      for $host in $doc/Host
      return
        <tr>
          <td>{ string($host/@RootRef) }</td>
          {
          for $i in ($steps, $finals)
          let $visible := string($i) = tokenize(string($doc/@AtStatus), " ")
          let $pre-action := if ($host/Action[@Type = 'update']) then 
                               $host/Action[@Type = 'update'] 
                             else (: inherited from parent :)
                               $doc/Action[@Type = 'update']
          let $action := $pre-action[string($i) = tokenize(string($doc/@AtStatus), " ")]
          let $roles := fn:doc($globals:application-uri)//Security//Document[@Root = string($host/@RootRef)]/Action[@Type = 'update']
          return
            <td>
              {
              if ($visible) then
                if ($action and $roles) then (
                  <p class="role">{string-join($roles/Meet/text(), " ")}</p>
                  )
                else
                  '-'
              else
                'x'
              }
            </td>
          }
        </tr>
      )
    }
  </tbody>
</table>
};

let $cmd := request:get-attribute('oppidum.command')
let $lang := 'en'
let $action := request:get-parameter('a', 'update')
let $root := request:get-parameter('r', 'Information')
let $pid := request:get-parameter('project', ())
let $case-no := request:get-parameter('case', ())
let $activity-no :=  request:get-parameter('activity', ())
let $p := fn:collection($globals:projects-uri)//Project[Id eq $pid]
let $case := if ($case-no) then $p//Case[No = $case-no] else ()
let $activity := if ($activity-no) then $case//Activity[No = $activity-no] else ()
return
  <div id="results">
    <style>
    table {{
      border-collapse: collapse;
      font-size: 16px;
      margin-bottom: 10px;
    }}
    td, th {{
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

    <p>View it <a href="{$cmd/@base-url}management/workflow">full window</a> (better for printing)</p>

    <h2>Definitions</h2>

    <ul>
    {
    for $role in fn:doc($globals:application-uri)//Description/Role
    return <li>{ $role/Name/text() } : { $role/Legend/text() }</li>
    }
    </ul>

    <p>Legend : </p>
    <p class="role" style="margin-bottom:0">role predicate of user allowed to change status or to edit</p>
    <p class="recipients" style="text-align:left; margin-top:0">role predicate of default alert message recipients</p>

    <h2>Access Control Transition Matrix</h2>
    <p>The workflow matrix shows you the current transition policy. In particular it explains the commands available in the <i>Goto next step</i> menu. Whenever changes are needed you should contact the database administrator <a href="mailto:s.sire@oppidoc.fr">s.sire@oppidoc.fr</a>.</p>
    <h3>Case workflow</h3>
    { local:gen-transition-table('Case', (1 to 3, 9, 10)) }
    <h3>Activity workflow</h3>
    { local:gen-transition-table('Activity', (1 to 11)) }

    <h2>Document access control matrix</h2>
    <p>X means document is not visible<br/>
- means document is visible but not editable<br/>
g:... or r:... means document is visible and editable when the corresponding role predicate is true<br/>
o means document is visible if it was visible in previous state</p>
    <h3>Case workflow</h3>
    { local:gen-document-table('Case', (1 to 3), (9, 10)) }
    <h3>Activity workflow</h3>
    { local:gen-document-table('Activity', (1 to 8), (9, 10, 11)) }

  </div>
