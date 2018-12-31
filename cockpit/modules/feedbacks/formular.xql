xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Displays a feedback form

   October 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../../xcm/modules/workflow/workflow.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   TODO: factorize with events/formular.xql ?
   ====================================================================== 
:)
declare function local:gen-event-title( $event as element() ) as xs:string {
  if (not($event/Name/@Extra)) then
    $event/Name
  else
    concat($event/Name, ' (', $event/*[local-name(.) = $event/Name/@Extra], ')')
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $tokens := tokenize($cmd/@trail, '/')
let $event-id := $tokens[3]
let $category := $tokens[4]
return
  let $event-def := fn:collection($globals:events-uri)//Event[Id eq $event-id]
  return
    if ($event-def) then
      let $target := string($cmd/resource/@name)
      let $title := local:gen-event-title($event-def/Information)
      return
        <Page StartLevel="1" skin="fonts extensions">
          <!--<LoginMenuOverlay Target="feedback"/>-->
          <Window>{ $title } feedback</Window>
          <Model>
            <Navigation>
              <Mode>dashboard</Mode>
              <Name>Feedback questionnaire for Investor</Name>
            </Navigation>
          </Model>
          <Content>
            <Title Level="1" style="margin-top: 0;margin-bottom:0">{ $title }</Title>
            <blockquote>
              <p>{ $event-def/Information/Location/Town/text() }, { $event-def/Information/Location/Country/text() }</p>
              <p>From { display:gen-display-date($event-def/Information/Date/From, 'en') } to { display:gen-display-date($event-def/Information/Date/To, 'en') }</p>
            </blockquote>
            {
            if ($target eq 'investors') then (
              oppidum:throw-message('INFO', 'Please complete this questionnaire then click on the submit button at the end. Once submitted you will not be able to correct your answers, so please double check your answers before submitting.'),
              <Editor data-autoscroll-shift="160" Id="feedback">
                <Template>../../../templates/feedback/investor?goal=update</Template>
                <Controller>investors</Controller>
              </Editor>
              )[last()]
            else 
              let $access := access:get-entity-permissions('export', 'Feedbacks', <Unused/>, $event-def)
              return
                if (local-name($access) eq 'allow') then
                  <Document Id="feedback">
                    <Template>../../../../templates/feedback/investor?goal=read</Template>
                    <Resource>{ $target }.data</Resource>
                  </Document>
                else
                  $access
            }
          </Content>
        </Page>
    else
      oppidum:throw-error("URI-NOT-SUPPORTED", ())
