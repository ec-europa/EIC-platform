xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Events search UI by EASME staff

   TODO: use access:check-*-permissions function for access control

   June 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $groups := oppidum:get-current-user-groups()
let $staff := $groups = ('admin-system', 'project-officer', 'developer', 'events-manager', 'dg')
return
  if ($staff) then
    <Page StartLevel="1" skin="fonts search extensions" Layout="ecl-container">
      <Window>Search Events</Window>
      <Model>
        <Navigation>
          <Mode>{ custom:get-dashboard-for-group($groups) }</Mode>
          <Key>events</Key>
          <Name>Search Events</Name>
        </Navigation>
      </Model>
      <Content>
        <Search>
          <Formular Id="editor" Width="100%">
            <Template loc="form.title.team.search">templates/event/search?goal=update</Template>
            <Commands>
              {
              if ($groups = ('admin-system', 'developer')) then
                <Button class="ecl-button ecl-button--default">
                  <Action>events/import</Action>
                  <Label>Import</Label>
                </Button>
              else
                ()
              }
              <Button class="ecl-button ecl-button--default">
                <Action>events/export</Action>
                <Label>Export</Label>
              </Button>
              {
              if (access:check-entity-permissions('manage', 'Events')) then
                <Button style="ecl-button ecl-button--primary">
                  <Action>events/management</Action>
                  <Label>Manage my events</Label>
                </Button>
              else
                ()
              }
              <Button data-command="table" data-target="editor" data-busy="spin-search" data-controller="events">
                <Label>Search</Label>
              </Button>
              <Clear Position="aside" class="ecl-button ecl-button--secondary" style="margin-left: 40px">
                <Label>Clear All</Label>
              </Clear>
            </Commands>
          </Formular>
          <SpinningWheel Id="spin-search">
            <Label>Loading event search results</Label>
          </SpinningWheel>
          <Search-Summary>events</Search-Summary>
          <Search-ResultsTable>events</Search-ResultsTable>
        </Search>
      </Content>
    </Page>
  else
    <Redirected>{ oppidum:redirect(concat($cmd/@base-url, enterprise:default-redirect-to($cmd/@trail))) }</Redirected>
    
