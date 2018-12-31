xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Generates page model for enterprises import by EASME staff

   May 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace search = "http://oppidoc.com/ns/application/search" at "search.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $m := request:get-method()
let $access := access:get-entity-permissions('import', 'Enterprise', <Unused/>) 
return
  if (local-name($access) eq 'allow') then
    <Page StartLevel="1" skin="fonts search">
      <Window>Import Companies</Window>
      <Model>
        <Navigation>
          <Mode>multi</Mode>
          <Name>Import Companies</Name>
        </Navigation>
      </Model>
      <Content>
        <Search>
          <Formular Id="editor" Width="680px">
            <Template loc="form.title.enterprises.search">../templates/enterprise/import?goal=update</Template>
            <Commands>
              <Button class="ecl-button ecl-button--default">
                <Action>../enterprises</Action>
                <Label>Back</Label>
              </Button>
              <Button data-command="table" data-target="editor" data-busy="spin-search" data-controller="import">
                <Label>Import</Label>
              </Button>
            </Commands>
          </Formular>
          <SpinningWheel Id="spin-search">
            <Label>Importing companies</Label>
          </SpinningWheel>
          <Import-Summary>imports</Import-Summary>
          <Import-ResultsTable>imports</Import-ResultsTable>
        </Search>
      </Content>
    </Page>
  else
    $access
