xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Generates user interface for several management functions

   May 2013 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $user := oppidum:get-current-user()
return
  <Page skin="management">
    <Window>Management</Window>
    <Model>
      <Navigation>
        <Mode>multi</Mode>
        <Key>admin</Key>
        <Name>Management</Name>
      </Navigation>
    </Model>
    <Content>
      <Tabs>
        <Tab Id="users" class="active">
          <Controller>management/users</Controller>
          <Name>Users</Name>
          <h2>Instructions to administrators</h2>
          <p>Start by clicking on a tab on the left to do something...</p>
          <p>If while interacting with this page you open other windows to update companies and/or persons, do not forget to click again on the tab to reload the changes !</p>
        </Tab>
        <Tab Id="login">
          <Controller>management/login</Controller>
          <Name>Login</Name>
          <Verbatim>
            <p>Click on the Login tab to actually load the latest access logs</p>
          </Verbatim>
        </Tab>
        <!-- FIXME: for admin system only
        <Tab Id="health">
          <Controller>health/check</Controller>
          <Name>Health</Name>
        </Tab>-->
      </Tabs>
      <Modals>
        <Modal Id="c-person-editor" data-backdrop="static" data-keyboard="false" Width="720">
          <Name>User account</Name>
          <Template>templates/account?goal=update&amp;realms=1</Template>
          <Commands>
            <Save data-replace-type="event"/>
            <Cancel/>
          </Commands>
        </Modal>
        <Modal Id="c-profile-editor" data-backdrop="static" data-keyboard="false" Width="960">
          <Name>User roles</Name>
          <Template>templates/roles?goal=update</Template>
          <Commands>
            <Save data-replace-type="event"><NoValidation/></Save>
            <Cancel/>
          </Commands>
        </Modal>
      </Modals>
    </Content>
  </Page>
