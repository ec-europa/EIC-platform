xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>

   Inspector routine to get information about configuration for developers.

   TODO: most probably this should be integrated into forthcoming event editor

   November 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   TODO: factorize
   ====================================================================== 
:)
declare function local:gen-event-title( $info as element()? ) as xs:string? {
  if (not($info/Name/@Extra)) then
    $info/Name
  else
    concat($info/Name, ' (', $info/*[local-name(.) = $info/Name/@Extra], ')')
};

(: ======================================================================
   Returns the Template element (path of XTiger template mesh questionnaire)
   to use with the Workflow's Document element passed as second parameter
   TODO: factorize with local:set-template in formular.xql
   ====================================================================== 
:)
declare function local:get-template-for( $event-def as element(), $doc-def as element() ) as xs:string {
  let $base := $doc-def/parent::Documents/@TemplateBaseURL
  let $tab := $doc-def/@Tab
  return
      if ($event-def/Processing/Document[@Tab eq $tab]/Template) then
        $event-def/Processing/Document[@Tab eq $tab]/Template
      else if ($tab eq 'apply' and $event-def/Template) then
        $event-def/Template
      else
        $doc-def/Template
};

(: ======================================================================
   TODO: factorize
   ====================================================================== 
:)
declare function local:generate-filename($event as element(), $what as xs:string) as xs:string {
  let $prg := $event/Programme/@WorkflowId
  let $event := $event/Information/Name
  return
    concat($prg, '_', $what, '_', replace($event, ' ', '_'), '-', fn:current-dateTime())
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $event-def := fn:collection($globals:events-uri)//Event[Id eq tokenize($cmd/@trail, '/')[2]]
let $prog-id := $event-def/Programme/@WorkflowId
let $workflow-app := fn:doc($globals:application-uri)//Workflow[@Id eq $prog-id]
let $selector := fn:collection($globals:global-info-uri)//Description[@Lang = $cmd/@lang]//Selector[@Name eq $prog-id]
return
  <Event>
    { $prog-id }
    <Title>{ local:gen-event-title($event-def/Information) }</Title>
    <Formulars>
    {
    for $doc in $workflow-app/Documents/Document
    let $template := local:get-template-for($event-def, $doc)
    (:let $doc-name := $selector/Option/Export[@Link eq $doc/@Tab]:)
    return
      element { $doc/@Tab} {
        normalize-space($template)
        }
    }
    </Formulars>
    <Notifications>
    {
    for $doc in $workflow-app/Documents/Document
    let $appear-at := tokenize($doc/@AtStatus, ' ')[1]
    return
      element { $doc/@Tab} {
        string-join(
          $workflow-app//Transition[@To eq $appear-at]/Email,
          ', ')
        }
    }
    </Notifications>
    <Validation>
    {
    for $doc in $workflow-app/Documents/Document
    let $appear-at := tokenize($doc/@AtStatus, ' ')[1]
    (: see also local:simple-get-transition-for in data.xql :)
    let $validator := $event-def/Processing/Document[@Tab eq $doc/@Tab]/Validate
    let $transitions := $workflow-app//Transition[@From eq $appear-at]
    return
      element { $doc/@Tab} {
        if ((some $t in $transitions satisfies $t/Assert/@Tab eq $doc/@Tab) and $validator) then
          $validator/text()
        else 
          for $t in $transitions/Assert
          return 
            if ($t/@Template) then 
              string($t/@Template)
            else
              $t/*
        }
    }
    </Validation>
    <Submit>
      <apply>
        {
        if ($event-def/Processing/Document[@Tab eq 'apply']/Create) then
          $event-def/Processing/Document[@Tab eq 'apply']/Create/text()
        else
          attribute { 'FIXME' } { "hardcoded in data.xql" }

        }
      </apply>
      <satisfaction FIXME="hardcoded per mapping.xml">satisfaction</satisfaction>
      <impact FIXME="hardcoded per mapping.xml">impact</impact>
    </Submit>
  </Event>
  
  
  
  
