xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Feedback formulars

   October 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

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
      let $title := local:gen-event-title($event-def/Information)
      return
        <Page StartLevel="1" skin="fonts">
          <!--<LoginMenuOverlay Target="feedback"/>-->
          <Window>{ $title } acknowledgment</Window>
          <Model>
            <Navigation>
              <Mode>dashboard</Mode>
              <Name>Feedback questionnaire for Investor</Name>
            </Navigation>
          </Model>
          <Content>
              <p style="font-size: 120%">Thank you for you contribution to the evaluation of { $title } !</p>
              <blockquote>
                 { $event-def/Information/Location/Town/text() }, { $event-def/Information/Location/Country/text() },
                 ({ display:gen-display-date($event-def/Information/Date/From, 'en') } - { display:gen-display-date($event-def/Information/Date/To, 'en') })
              </blockquote>
          </Content>
        </Page>
    else
      oppidum:throw-error("URI-NOT-SUPPORTED", ())
      
