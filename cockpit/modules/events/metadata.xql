xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   CRUD controller to manage the event metadata
   - generates XTiger template pre-filled with current values as default values
   - saves event meta data

   FIXME: 
   - implement access control (actually any registered user can GET /form/nb/edit.template
     and POST to /form/nb/edit)

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

declare option exist:serialize "method=xml media-type=application/xhtml+xml";

declare variable $local:nodes-exclusion := ('CreatedByRef', 'CreatedFromKey', 'Rankings', 'FinalRankings', 'Applicants', 'Accepted', 'Processing');
(: DEPRECATED: 'Applicants', 'Accepted' => 'Rankings' :)
(: TODO: find better trick than a list to filter out non editable nodes ? :)

(: ======================================================================
   Simple recursive incremental update of element lists value when it differs
   Match elements on node names so there must not be siblings with same tag name
   ====================================================================== 
:)
declare function local:save-nodes-iter( $input as element()*, $legacy as element()* ) {
  for $cur in $input
  let $tag := local-name($cur)
  let $target := $legacy[local-name() eq $tag]
  where exists($target)
  return (
    (: updates attributes :)
    for $a in $cur/attribute::*
    let $attribute := $target/attribute::*[local-name() eq local-name($a)]
    where exists($attribute) and (string($attribute) ne string($a))
    return update value $attribute with string($a),
    (: updates children or text content :)
    if ($cur[child::element()]) then
      local:save-nodes-iter($cur/*, $target/*)
    else if ($cur ne $target) then
      update value $target with $cur/text()
    else
      ()
    )
};

(: ======================================================================
   TODO: use a 'event-meta-data' data template for validation
   ====================================================================== 
:)
declare function local:save-data( $submitted as element(), $source as element() ) {
  let $redirect := $submitted/Information/Name ne $source/Information/Name
                   or
                   $submitted/Information/Application/From ne $source/Information/Application/From
                   or 
                   $submitted/Information/Application/To ne $source/Information/Application/To
                   or
                   $submitted/PublicationStateRef ne $source/PublicationStateRef
  let $rec := count(globals:collection('enterprises-uri')//Enterprise//Event[Id = $source/Id])
  return
    (: FIXME: hard coded validation and guard Programme :)
    if (($rec > 0) and ($submitted/Programme/@WorkflowId ne $source/Programme/@WorkflowId)) then 
      oppidum:throw-error('CUSTOM', concat('You cannot change the event workflow since ', $rec, ' application(s) have already been saved or submitted'))
    else if ($submitted/Template ne $source/Template) then
      if ($rec > 0) then
        oppidum:throw-error('CUSTOM', concat('You cannot change the event application template  since ', $rec, ' application(s) have already been saved or submitted'))
      else
        oppidum:throw-error('CUSTOM', 'With the current version of the application you need to ask a database administrator to change the event application template  since this implies to edit some configuration data not available in this window')
      
    else (
      local:save-nodes-iter($submitted/*, $source/*),
      if ($redirect) then
        (: TODO: return payload to update Name with Ajax if changed instead or redirection :)
        ajax:report-success-redirect('ACTION-UPDATE-SUCCESS', (), 'management')
      else
        ()
      )
};

(: ======================================================================
   Generates XTiger selector to edit the application template
   The list of application templates is actually the intersection between
   custom templates developped event by event and standard templates 
   ====================================================================== 
:)
declare function local:gen-application-template-selector( $template as element()? ) as element(xt:use) {
  (:
  TODO: could be restored in the future
  let $xtuse := form:gen-selector-for('EventsApplicationTemplates', 'en', '')
  let $others:=  
    for $i in distinct-values(fn:collection('/db/sites/cockpit/events')//Event/Template)
    where not(starts-with($i, 'standard'))
    return 
      <Name id="{$i}">{(replace(concat('(legacy) - ', replace($i, '[/-]', ' ')),' ','\\ '))}</Name>
  return
    <xt:use values="{$xtuse/@values} {string-join(for $n in $others return string($n/@id), ' ')}" i18n="{$xtuse/@i18n} {string-join(for $n in $others return $n/text(), ' ')}">:)
    <xt:use types="constant" param="class=uneditable-input span" _Output="{ $template/text() }">
      {
      if (exists($template/@ProjectKeyTag)) then 
        () (: label will be generated through component to hold attribute :)
      else
        attribute { 'label' } { 'Template' },
      (:$xtuse/(@types | @param),:)
      $template/text()
      }
    </xt:use>
};

(: ======================================================================
   Generates the EventsProgrammes selector with pre-selected default value
   ====================================================================== 
:)
declare function local:gen-programme-selector( $cur-value as xs:string? ) as element(xt:use) {
  (:
  TODO: could be restored in the future
  let $xtuse := form:gen-selector-for('EventsPrograms', 'en', '')
  return :)
    <xt:attribute name="WorkflowId" types="constant" param="class=uneditable-input span" _Output="{ $cur-value }" default="{ $cur-value }"/>
    (:{ $xtuse/(@*|*) }
    </xt:attribute>:)
};

(: ======================================================================
   Generates a selectors hash with the selectors required to edit event meta data
   Generates a label map to allow explicit field labelling in the UI
   registered as a '#labels' entry

   Attention : quand mettre un label sur xt:use de programme ?
   ====================================================================== 
:)
declare function local:gen-selectors-map ( $event-def as element() ) as map() {
  map:new((
    map:entry(
      'Template',
      local:gen-application-template-selector($event-def/Template)
      ),
    map:entry(
      'Programme',
      <xt:use types="input" param="class=span a-control">{ $event-def/Programme/text() }</xt:use>
      ),
    map:entry(
      'WorkflowId',
      local:gen-programme-selector($event-def/Programme/@WorkflowId)
      ),
    map:entry(
      'PublicationStateRef',
      let $xtuse := form:gen-selector-for('PublicationStates', 'en', '')
      return <xt:use label="PublicationStateRef">{ $xtuse/@*, $event-def/PublicationStateRef/text() }</xt:use>
      ),
    map:entry(
      '#labels',
      map:new((
        map:entry('WorkflowId', 'Workflow'),
        map:entry('ProjectKeyTag', 'Project key tag (legacy imported event)'),
        map:entry('Template', 'Application formular template'),
        map:entry('Programme', 'Programme name'),
        map:entry('DateFrom', 'Event start date'),
        map:entry('DateTo', 'Event end date'),
        map:entry('ApplicationFrom', 'Registration from'),
        map:entry('ApplicationTo', 'Registration to')
        ))
      )
  ))
};

(: ======================================================================
   Build the template for editing the (sub)tree node
   ====================================================================== 
:)
declare function local:gen-mesh-for-editing($event-def as element()) as element() {
  let $data := element { local-name($event-def) } { $event-def/*[not(local-name(.) = $local:nodes-exclusion)] } 
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
          {
          mesh:embedding(mesh:compact(mesh:transform($data, local:gen-selectors-map($data))))
          }
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
let $event-def := fn:collection($globals:events-uri)//Event[Id eq tokenize($cmd/@trail, '/')[2]]
return
  if ($m eq 'POST') then
    let $res := local:save-data(oppidum:get-data(), $event-def)
    return
      if (local-name($res) ne 'error') then
        if (local-name($res) ne 'success') then
          ajax:report-success('ACTION-UPDATE-SUCCESS', ())
        else
          $res
      else
        $res
  else if ($template) then
    let $allow := oppidum:get-current-user-groups() = ( 'admin-system', 'project-officer', 'developer' )
    return
      if ($allow) then
        local:gen-mesh-for-editing($event-def)
      else
        ()
  else (: useless as data is preloaded during init of the mesh :)
    <Event/> 
