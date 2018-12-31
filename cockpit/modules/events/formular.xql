xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Displays a single event application workflow

   TODO: rename as event.xql ?

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../../xcm/modules/workflow/workflow.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:set-template( $event-def as element(), $doc-def as element(), $enterprise as element() ) as xs:string {
  local:set-template( $event-def, $doc-def, $enterprise, 'read')
};

(: ======================================================================
   Configure Template element for a questionnaire, taking by priority:
   First, the Template element of the Document of the Processing element of 
   the event meta-data if it exists,
   (TODO: DEPRECATED) Second, in case of 'apply' Tab and beneficiary company,
   the Template element of the event meta-data if it exists,
   Third, the Template element from the Document definition in application.xml
   ====================================================================== 
:)
declare function local:set-template( $event-def as element(), $doc-def as element(), $enterprise as element(), $verb as xs:string ) as xs:string {
  let $processing := custom:get-event-processing($event-def, $enterprise)
  let $base := $doc-def/parent::Documents/@TemplateBaseURL
  let $tab := $doc-def/@Tab
  return
    concat($base,
      if (exists($processing/Document[@Tab eq $tab]/Template)) then
        $processing/Document[@Tab eq $tab]/Template
      else if ($tab eq 'apply' and $event-def/Template and not(enterprise:is-a($enterprise, 'Investor'))) then
        $event-def/Template (: DEPRECATED :)
      else if (exists($doc-def/Template)) then  (: no possible discrimination on company type :)
        $doc-def/Template
      else
        oppidum:throw-error('CUSTOM', concat('Wrong template configuration for ', $verb)),
      '?goal=', $verb,
      '&amp;enterprise=', $enterprise/Id,
      '&amp;event=', $event-def/Id)
};

declare function local:visibility( $doc-def as element(), $status as xs:string ) as xs:string {
  if (tokenize(string($doc-def/@AtStatus), " ")  = $status or tokenize(string($doc-def/@AtFinalStatus), " ") = $status) then
    'on'
  else
    'off'
};

declare function local:gen-event-title( $event as element() ) as xs:string {
  if (not($event/Name/@Extra)) then
    $event/Name
  else
    concat($event/Name, ' (', $event/*[local-name(.) = $event/Name/@Extra], ')')
};

(: ======================================================================
   Generates Document elements to render in the event application accordion
   Interprets application.xml rules to generate the supported actions

   FIXME: at some point replace workflow stateless access:check-tab-permission
          by stateful check-workflow-permissions) ?

   See also workflow:gen-information in XCM modules/workflow/workflow.xqm
   ====================================================================== 
:)
declare function local:gen-documents( $event-def as element(), $enterprise as element() ) as element()* {
  let $prog-id := $event-def/Programme/@WorkflowId
  let $workflow-sel := fn:collection($globals:global-info-uri)//Selector[@Name eq $prog-id]
  let $workflow-app := fn:doc($globals:application-uri)//Workflow[@Id eq $prog-id]
  let $event-application := $enterprise/Events/Event[Id = $event-def/Id]
  let $current-status := if (not($event-application) or not($event-application/StatusHistory/CurrentStatusRef)) then '1' else $event-application/StatusHistory/CurrentStatusRef
  return 
    for $doc-def in $workflow-app//Document[not(@Deprecated)][(tokenize(string(@DimAtStatus), " "), tokenize(string(@AtStatus), " ")) = $current-status]
    let $actions := 
      for $a in $doc-def/Action
      where tokenize(string($a/@AtStatus), " ") = $current-status
      return $a
    let $editor-id := concat('event-form-', $doc-def/@Tab, '-', $event-def/Id)
    return
      <Document>
        {
        $doc-def/@class,
        $doc-def/@data-autoscroll-shift,
        attribute Status { local:visibility($doc-def, $current-status) },
        (: quick implementation to pre-open an accordion document :)
        if ($doc-def/@PreOpenAtStatus and $doc-def/@PreOpenAtStatus eq $current-status) then
          attribute  { 'data-accordion-status' } { 'opened' }
        else 
          (),
        attribute Id { $editor-id },
        <Name>
          {
          if ($doc-def/@loc) then 
            $doc-def/@loc
          else
            attribute { 'loc' } { concat('workflow.', lower-case($prog-id), '.title.', $doc-def/@Tab) },
          string($doc-def/@Tab)
          }
        </Name>,
        <Resource>{ $doc-def/Resource/text() }.blend?goal=read</Resource>,
        <Template>{ local:set-template($event-def, $doc-def, $enterprise) }</Template>,
        <Actions>
          {
          for $spec in $actions[@Type = ('update', 'status')]
          let $action := string($spec/@Type)
          return
            if ($action eq 'update') then
              if (access:check-tab-permissions($action, $doc-def/@Tab, $enterprise, $event-application)) then
                <Edit data-no-validation-inside=".hide">
                  { $spec/@Forward }
                  { $spec/@To }
                  <Resource>{ $doc-def/Resource/text() }.xml?goal=read</Resource>
                  <Template>{ local:set-template($event-def, $doc-def, $enterprise, 'update') }</Template>
                </Edit>
              else (: not allowed :)
                ()
            else if (exists($event-application) and ($action eq 'status')) then
              (: target-modal parameter will not be used (<done/> Ajax response) however is required 
                 by the AXEL 'command' API, see accordion.xsl for the prefix 'c-editor-' :)
              workflow:gen-status-change(number($current-status), $prog-id, $enterprise, $event-application, (), concat('c-editor-', $editor-id))
            else
              ()
          }
        </Actions>,
        if ($doc-def/AutoExec/@AtStatus eq $current-status) then $doc-def/AutoExec else ()
        }
      </Document>
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $tokens := tokenize($cmd/@trail, '/')
let $enterprise-id := $tokens[2]
return
  if ($tokens[1] eq 'form') then (: anonymous request from easme ??? Yes! :)
    let $enterprise := enterprise:get-my-enterprises()[1]
    return
      <Redirected>
        { 
        oppidum:redirect(concat($cmd/@base-url, 'events/', $enterprise/Id,  '/form/', $enterprise-id))
        }
      </Redirected>
  else
    let $event-def := fn:collection($globals:events-uri)//Event[Id eq $tokens[4]]
    return
      if (not($event-def)) then
        <Redirected>
          {
          let $side-effect := oppidum:add-error('URI-NOT-FOUND', (), true())
          return
            oppidum:redirect(concat($cmd/@base-url, 'events/', $enterprise-id))
          }
        </Redirected>
      else
        let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $enterprise-id]
        return
          if (access:check-entity-permissions('view', 'Event', $enterprise, $event-def)
              and enterprise:can-apply-to-event($enterprise, $event-def)) then
            let $today := substring(string(current-date()),1,10)
            let $groups := oppidum:get-current-user-groups()
            let $staff := $groups = ('admin-system', 'project-officer', 'developer')
            let $crawler := not($staff) and $groups = ('events-manager')
            let $opened := true() (: $staff or $crawler or $event-def//Application[From le $today and $today le To] :)
            let $id := tokenize($cmd/@trail, '/')[2]
            let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $id]
            let $title := custom:gen-enterprise-title($enterprise)
            return
              if ($opened) then
                <Page StartLevel="1" skin="fonts extensions accordion dropzone" ResourceName="{ tokenize($cmd/@trail, '/')[4] }">
                  <Window>{ $event-def/Information/Name } participation</Window>
                  <Model>
                    <Navigation>
                      <Mode>{ if ($crawler) then 'evmgr-single' else 'single' }</Mode>
                      <Resource>{ $enterprise-id }</Resource>
                      <Name>{ $title }</Name>
                    </Navigation>
                  </Model>
                  <Content>
                    <Title Level="1" class="ecl-heading ecl-heading--h1">{ concat('Application to ', local:gen-event-title($event-def/Information)) }</Title>
                    <p class="text-info" style="margin-bottom:20px"><i>Click on a horizontal bar to view or hide its content. Click on Edit to change its content.</i></p>
                    <Verbatim/>
                    <Accordion>{ local:gen-documents($event-def, $enterprise) }</Accordion>
                  </Content>
                  <Dictionary>
                    <WorkflowStatus>
                    {
                    let $prog-id := $event-def/Programme/@WorkflowId
                    let $workflow-sel := fn:collection($globals:global-info-uri)//Selector[@Name eq $prog-id]
                    return $workflow-sel/Option
                    }
                    </WorkflowStatus>
                  </Dictionary>
                </Page>
              else
                <Redirected>
                  { 
                  let $side-effect := oppidum:add-error('CUSTOM', 'You cannot access to the registration form as we are outside the registration period of the event', true())
                  return
                    oppidum:redirect(concat($cmd/@base-url, 'events/', $enterprise-id)) 
                  }
                </Redirected>
          else
            oppidum:throw-error('FORBIDDEN', ())
