xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Enterprise overview page for users
   Shows tab view for updating enterprise data

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $id := string($cmd/resource/@name)
let $enterprise := globals:collection('enterprises-uri')//Enterprise[Id eq $id]
let $access := access:get-entity-permissions('view', 'Enterprise', $enterprise)
let $title := custom:gen-enterprise-title($enterprise)
return
  if (local-name($access) eq 'allow') then
    (: FIXME: we could use check-tab-permissions to fine tune tabs / commands generation if necessary :)
    <Page StartLevel="1" skin="fonts extensions accordion" ResourceName="{ $id }">
      <Window>{ $title }</Window>
      <Model>
        <Navigation>
          <Mode>single</Mode>
          <Key>company</Key>
          <Resource>{ $id }</Resource>
          <Name>{ $title }</Name>
        </Navigation>
      </Model>
      <Content>
        <Tabs Id="sme-tabs">
          <Tab Id="sme-profile-tab" class="active">
            <Name>Profile</Name>
            <Accordion>
              <Document Id="company-address">
                <Name loc="data.enterprise.address">Address</Name>
                <Resource>address.xml?goal=read</Resource>
                <Template>../templates/enterprise/address?goal=read{ if (enterprise:is-a($enterprise, 'Investor')) then "&amp;iso3=1" else () }</Template>
                {
                if (access:check-tab-permissions('update', 'cie-address', $enterprise)) then
                  <Actions>
                    <Edit>
                      <Resource>address.xml?goal=update</Resource>
                      <Template>../templates/enterprise/address?goal=update{ if (enterprise:is-a($enterprise, 'Investor')) then "&amp;iso3=1" else () }</Template>
                    </Edit>
                  </Actions>
                else
                  ()
                }
              </Document>
              <Document Id="company-statistics">
                <Name loc="data.enterprise.companyProfile">Company profile</Name>
                <Resource>statistics.xml?goal=read</Resource>
                <Template>../templates/enterprise/statistics?goal=read</Template>
                {
                if (access:check-tab-permissions('update', 'cie-statistics', $enterprise)) then
                  <Actions>
                    <Edit>
                      <Resource>statistics.xml?goal=update</Resource>
                      <Template>../templates/enterprise/statistics?goal=update</Template>
                    </Edit>
                  </Actions>
                else
                  ()
                }
              </Document>
            </Accordion>
          </Tab>
          <!--<Tab Id="sme-evolution-tab">
            <Name>Evolution</Name>
            <Verbatim>
              <Title Level="3">Size</Title>
              <p style="font-size:120%">Graph will be available soon</p>
              <Title Level="3">Public funding</Title>
              <p style="font-size:120%">Graph will be available soon</p>
              <Title Level="3">Private investments</Title>
              <p style="font-size:120%">Graph will be available soon</p>
            </Verbatim>
          </Tab>
          <Tab Id="sme-partners-tab">
            <Name>Partners</Name>
            <Verbatim>
              <Title Level="2">Partners</Title>
              <p style="font-size:120%">Will be available soon</p>
            </Verbatim>
          </Tab>-->
          {
          if (access:check-tab-permissions('update', 'cie-status', $enterprise)) then
            let $flag := if ($enterprise/Settings/Teams eq 'Investor') then '&amp;invest=1' else ()
            return
              <Tab Id="sme-status-tab">
                <Name>Status</Name>
                <!-- TODO : Document alone widget !!! -->
                <Accordion>
                  <Document Id="company-status">
                    <Name loc="data.enterprise.status">Current Status</Name>
                    <Resource>status.blend?goal=read</Resource>
                    <Template>../templates/enterprise/status?goal=read{ $flag }</Template>
                    <Actions>
                      <Edit>
                        <Resource>status.xml?goal=update</Resource>
                        <Template>../templates/enterprise/status?goal=update{ $flag }</Template>
                      </Edit>
                    </Actions>
                  </Document>
                </Accordion>
              </Tab>
          else
            ()
          }
        </Tabs>
      </Content>
    </Page>
  else
    $access

