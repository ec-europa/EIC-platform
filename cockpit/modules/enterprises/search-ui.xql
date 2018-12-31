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
let $staff := oppidum:get-current-user-groups() = ('admin-system', 'project-officer', 'developer','dg')
return
  if ($staff) then
    <Page StartLevel="1" skin="fonts search extensions" Layout="ecl-container">
      <Window>Search Companies</Window>
      <Model>
        <Navigation>
          <Mode>{ custom:get-dashboard-for-group($groups) }</Mode>
          <Key>companies</Key>
          <Name>Search Companies</Name>
        </Navigation>
      </Model>
      <Layout></Layout>
      <Content>
        <Search>
          <Formular Id="editor" Width="100%">
            <Template loc="form.title.enterprises.search">templates/enterprise/search?goal=update</Template>
            <Commands>
              {
              if (access:check-entity-permissions('add', 'Investor')) then
                <Button class="ecl-button ecl-button--default" data-command="confirm" data-confirm="Are you sure ?" data-src="enterprises/create">
                  <Label>Create investor</Label>
                </Button>
              else
                ()
              }
              <Button data-command="table" data-target="editor" data-busy="spin-search" data-controller="enterprises">
                <Label>Search</Label>
              </Button>
            </Commands>
          </Formular>
          <SpinningWheel Id="spin-search">
            <Label>Loading company search results</Label>
          </SpinningWheel>
          <Search-Summary>companies</Search-Summary>
          <Search-ResultsTable>companies</Search-ResultsTable>
    <!--        <Modals>
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
    
    


