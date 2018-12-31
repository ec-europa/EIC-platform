xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   CRUD controller to manage Applicant score and comments in ranking list editor
   - generates XTiger template pre-filled with current values as default values
   - saves event meta data

   August 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace mesh = "http://oppidoc.com/ns/mesh" at "../../lib/mesh.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/xcm/misc" at "../../../xcm/lib/util.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../../xcm/modules/workflow/workflow.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   FIXME: submitting an empty Comment causes Text to disappear 
          and field to be turned to single line text field the next time
   ====================================================================== 
:)
declare function local:save-data( $submitted as element(), $source as element(), $enterprise-ref as xs:string ) {
  let $applicant := $source/Rankings[@Iteration eq 'cur']//Applicant[EnterpriseRef eq $enterprise-ref]
  let $ranking-comm := $applicant/EvaluatorComment
  return
    (
    if (not($ranking-comm)) then 
      update insert $submitted into $applicant
    else
      update replace $ranking-comm with $submitted,
    if ($ranking-comm) then
      <Already Id="{$enterprise-ref}" />
    else if ($submitted//Score/text() ne '' or $submitted//Comment/Text) then
      <Filled Id="{$enterprise-ref}"/>
    else
      <Empty Id="{$enterprise-ref}"/>
    )
    
};

(: ======================================================================
   Generates a selectors hash with the selectors required to edit event meta data
   Use this to map drop down list selectors to some tag names
   ====================================================================== 
:)
declare function local:gen-selectors-map ( $event-def as element() ) as map() {
  map:new()
};

(: ======================================================================
   Build the template for editing the (sub)tree node
   ====================================================================== 
:)
declare function local:gen-mesh-for-editing($node as element()) as element() {
  let $data := element { local-name($node) } { $node/* } 
  let $root := local-name($data)
  return
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:site="http://oppidoc.com/oppidum/site" xmlns:xt="http://ns.inria.org/xtiger" xmlns:xhtml="http://www.w3.org/1999/xhtml">
      <head>
        <meta http-equiv="content-type" content="text/html; charset=UTF-8" />
        <title></title>
        <link rel="stylesheet" type="text/css" href="../resources/bootstrap/css/bootstrap.css"/>
        <link rel="stylesheet" type="text/css" href="../resources/bootstrap/css/bootstrap-responsive.css"/>
        <link rel="stylesheet" type="text/css" href="../resources/bootstrap/css/bootstrap-responsive.min.css"/>
        <link rel="stylesheet" type="text/css" href="../resources/css/site.css"/>
        <link rel="stylesheet" type="text/css" href="../resources/css/forms.css"/>
        <link rel="stylesheet" type="text/css" href="../resources/css/index.css"/> 
        <xt:head version="1.1" templateVersion="1.0" label="{ $root }">
          <xt:component name="t_main">
            <form action="" onsubmit="return false;" tabindex="-1">
              <xt:use types="{ $root }"/>
            </form>
          </xt:component>
          { mesh:embedding(mesh:compact(mesh:transform($data, local:gen-selectors-map($data)))) }
        </xt:head>
      </head>
      <body>
        <xt:use types="t_main"/>
      </body>
    </html>
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $m := request:get-method()
let $template := string($cmd/@format) eq 'template'
let $event-def := fn:collection($globals:events-uri)//Event[Id eq tokenize($cmd/@trail, '/')[4]]
let $ranking-comm := $event-def/Rankings[@Iteration eq 'cur']//Applicant[EnterpriseRef eq tokenize($cmd/@trail, '/')[2]]/EvaluatorComment
return
  if ($m eq 'POST') then
    let $res := local:save-data(oppidum:get-data(), $event-def, tokenize($cmd/@trail, '/')[2])
    return
      if (local-name($res) ne 'error') then
        if (local-name($res) ne 'success') then
          ajax:report-success('ACTION-UPDATE-SUCCESS', (), $res)
        else
          $res
      else
        $res
  else if ($template) then
    let $allow := oppidum:get-current-user-groups() = ( 'admin-system', 'project-officer', 'developer', 'events-manager', 'events-supervisor' )
    return
      if ($allow) then
        local:gen-mesh-for-editing(
          if (not($ranking-comm)) then
            <EvaluatorComment>
              <Score/>
              <Comment>
                <Text/>
              </Comment>
            </EvaluatorComment>
          else
            $ranking-comm
        )
      else
        ()
  else (: useless as data is preloaded during init of the mesh :)
    <EvaluatorComment/> 
    
