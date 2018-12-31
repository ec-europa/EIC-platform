xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Displays a self-registration form

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

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $tokens := tokenize($cmd/@trail, '/')
(:let $warning := oppidum:throw-message('INFO', 'You have just complete the registration questionnaire.'):)
let $profile := user:get-user-profile()
return

 if ($profile and exists($profile//AdmissionKey) and exists($profile//Role[descendant::FunctionRef eq '9'])) then
        <Page StartLevel="1" skin="fonts extensions">
          <!--<LoginMenuOverlay Target="feedback"/>-->
          <Window>Investor registration submitted</Window>
          <Content>
            <Title Level="1" class="ecl-heading">Investor registration completed</Title>
            <p>You have just complete the registration form.</p>
          </Content>
        </Page>
 else
    oppidum:throw-error('FORBIDDEN', ())
 
