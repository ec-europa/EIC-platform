xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Generates page model for enterprises search by EASME staff

   TODO: 
   - make Submission module compatible with Ajax JSON Table protocol
   - invent 'table' command for Search button compatible with makeTableCommand widget

   April 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace search = "http://oppidoc.com/ns/application/search" at "search.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := oppidum:get-command()
let $m := request:get-method()
let $groups := oppidum:get-current-user-groups()
(: TODO: configure access control in application.xml and use access:check-*-permissions :)
let $staff := oppidum:get-current-user-groups() = ('admin-system', 'project-officer', 'developer', 'dg')
return
  if ($staff) then
    <Page StartLevel="1" skin="fonts search extensions" Layout="ecl-container">
      <Window>Search Members</Window>
      <Model>
        <Navigation>
          <Mode>{ custom:get-dashboard-for-group($groups) }</Mode>
          <Key>teams</Key>
          <Name>Search Members</Name>
        </Navigation>
      </Model>
      <Content>
        <Search>
          <Formular Id="editor" Width="100%">
            <Template loc="form.title.team.search">templates/team/search?goal=update</Template>
            <Commands>
              {
              if (access:check-entity-permissions('import', 'PO')) then
                <Button class="ecl-button ecl-button--default" data-command="table" data-target="editor" data-busy="spin-import" data-controller="officers">
                  <!-- FIXME: data-target not really used -->
                  <Label>Import PO</Label>
                </Button>
              else
                (),
              if (access:check-entity-permissions('import', 'LEAR')) then
                <Button class="ecl-button ecl-button--default">
                  <Action>teams/import</Action>
                  <Label>Import LEAR</Label>
                </Button>
              else
                ()
              }
              <Button data-command="table" data-target="editor" data-busy="spin-search" data-controller="teams">
                <Label>Search</Label>
              </Button>
            </Commands>
          </Formular>
          <SpinningWheel Id="spin-import">
            <Label>Importing project officers from Case Tracker</Label>
          </SpinningWheel>
          <SpinningWheel Id="spin-search">
            <Label>Loading results</Label>
          </SpinningWheel>
          <Search-Summary>members</Search-Summary>
          <Search-ResultsTable>members</Search-ResultsTable>
<!--      DEPRECATED
          <Search-Investors-Summary>investors</Search-Investors-Summary>
          <Search-Investors-ResultsTable>investors</Search-Investors-ResultsTable> -->
          <Search-Entries-Summary>entries</Search-Entries-Summary>
          <Search-Entries-ResultsTable>entries</Search-Entries-ResultsTable>
          <Search-Tokens-Summary>tokens</Search-Tokens-Summary>
          <Search-Tokens-ResultsTable>tokens</Search-Tokens-ResultsTable>
          <Search-Unaffiliated-Summary>unaffiliated</Search-Unaffiliated-Summary>
          <Search-Unaffiliated-ResultsTable>unaffiliated</Search-Unaffiliated-ResultsTable>
          <Import-Summary>officers</Import-Summary>
          <Import-ResultsTable>officers</Import-ResultsTable>
<!--      <Modals>
            <Modal Id="c-item-viewer" Goal="read">
              <Template>templates/team/member</Template>
              <Commands>
                <Button Id="c-modify-btn" loc="action.edit"/>
                <Close/>
              </Commands>
            </Modal>
          </Modals> -->
        </Search>
      </Content>
    </Page>
  else
    <Redirected>{ oppidum:redirect(concat($cmd/@base-url, enterprise:default-redirect-to($cmd/@trail))) }</Redirected>


