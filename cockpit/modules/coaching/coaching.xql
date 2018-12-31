xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Coaching overview page for users
   Shows tab view with coaching related information

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Generates tabs for tracking coaching in each project
   ====================================================================== 
:)
declare function local:gen-coaching-tabs( $enterprise as element() ) as element()* {
  for $project in $enterprise//Project
  return
    <Tab Id="sme-coaching-1-tab" Display="off">
      <Name>{ $project/Acronym/text() }</Name>
    </Tab>
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $profile := user:get-user-profile()
let $id := string($cmd/resource/@name)
let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $id]
let $title := custom:gen-enterprise-title($enterprise)
return
  if (access:check-entity-permissions('view', 'Enterprise', $enterprise)) then
    <Page StartLevel="1" skin="fonts extensions accordion" ResourceName="{ $id }">
      <Window>{ $title } coaching</Window>
      <Header>
      <Title Level="1">
          <Home>../{ $id }</Home>
          { $title } Coaching</Title>
      </Header>
      <Content>
        <Tabs Id="sme-tabs">
          <Tab Id="sme-coaching-tab" class="active">
            <Name>Overview</Name>
            <Verbatim>
              <p>This page keeps you informed of the advancement of the coaching offers  concerning your SME Instrument projects.</p>
              <table class="table table-bordered">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Project</th>
                    <th>Status</th>
                    <th>Next step</th>
                    <th>Action</th>
                  </tr>
                  <tr>
                    <td>{ display:gen-display-date(string(current-dateTime()), 'en') }</td>
                    <td><i>pending</i></td>
                    <td><i>pending</i></td>
                    <td>The next step will be to assign your project to the Enterprise Europe Network (EEN) team in your region (see <a target="_blank" href="http://een.ec.europa.eu/about/branches">EEN branches</a>)</td>
                    <td>The contact person recorded in the project description will receive a notification e-mail upon EEN assignment</td>
                  </tr>
                </thead>
              </table>
            </Verbatim>
          </Tab>
          { local:gen-coaching-tabs($enterprise) }
        </Tabs>
      </Content>
    </Page>
  else
    oppidum:throw-error('FORBIDDEN', ())
