xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Generates user interface for several management functions

   May 2013 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: Deprecated legacy

<Tab Id="thesaurus">
  <Controller>management/thesaurus</Controller>
  <Name>Thesaurus</Name>
</Tab>

<Edit Id="c-thesaurus-editor" Width="800">
  <Name>Thesaurus</Name>
  <Template>management/thesaurus?template=1</Template>
</Edit>
:)

let $user := oppidum:get-current-user()
return
  <Page skin="management">
    <Window>Case Tracker Administration</Window>
    <Content>
      <Verbatim>
        <p id="cm-import-busy" class="spinning" style="display:none;margin-left:400px;padding-left:50px" loc="term.loading">Loading...</p>
      </Verbatim>
      <Tabs>
        <Tab Id="users" class="active">
          <Controller>management/users</Controller>
          <Name>Users</Name>
          <h2>Instructions to administrators</h2>
          <p>Start by clicking on a tab on the left to do something...</p>
          <p>If while interacting with this page you open other windows to update companies and/or persons, do not forget to click again on the tab to reload the changes !</p>
        </Tab>
        <Tab Id="remotes">
          <Controller>management/remotes</Controller>
          <Name>Remote Users</Name>
        </Tab>
        <Tab Id="cm-import-tab">
          <Name>Import</Name>
          <Title Level="1">Users importation</Title>
          <Text>Click on the letter index to fetch a list of coaches with a surname starting by that letter from the CoachCom2020 Case Tracker</Text>
          <Verbatim>
            <p Id="cm-import-index" style="text-align:center;margin: 1.5em 0">
              {
              for $i in (1 to 26) 
              return 
              <a href="#{ codepoints-to-string(64 + $i) }" style="padding-right:10px">{ codepoints-to-string(64 + $i) }</a>
              }
            </p>
            <p id="cm-import-feedback" style="text-align:center;display:none">Found <span>X</span> coach(es) starting with letter <span>Y</span></p>
          </Verbatim>
          <Management-ImportResults/>
        </Tab>
        {
        if ($user = 'admin') then (
          <Tab Id="params">
            <Controller>management/params</Controller>
            <Name>Parameters</Name>
          </Tab>,
          <Tab Id="groups">
            <Controller>management/groups</Controller>
            <Name>Groups</Name>
          </Tab>
          )
        else
          ()
        }
        <Tab Id="roles">
          <Controller>management/roles</Controller>
          <Name>Roles</Name>
        </Tab>
        <Tab Id="login">
          <Controller>management/login</Controller>
          <Name>Login</Name>
        </Tab>
        <Tab Id="access">
          <Controller>management/access</Controller>
          <Name>Access</Name>
        </Tab>
        <Tab Id="health">
          <Controller>health/check</Controller>
          <Name>Health</Name>
        </Tab>
        <Tab Id="workflow">
          <Controller>management/workflow</Controller>
          <Name>Workflow</Name>
        </Tab>
        <Tab Id="roadmap">
          <Controller>specs/roadmap</Controller>
          <Name>Roadmap</Name>
        </Tab>
      </Tabs>
      <Modals>
        <Modal Id="c-item-editor" data-backdrop="static" data-keyboard="false">
          <Name>Add a new person</Name>
          <Template>templates/person?goal=create&amp;realms=1</Template>
          <Commands>
            <Save data-replace-type="event"/>
            <Cancel/>
            <Clear/>
          </Commands>
        </Modal>
        <Modal Id="c-person-editor" data-backdrop="static" data-keyboard="false">
          <Name>Update person record</Name>
          <Template>templates/person?goal=update&amp;realms=1</Template>
          <Commands>
            <Delete/>
            <Save data-replace-type="event"/>
            <Cancel/>
          </Commands>
        </Modal>
        <Modal Id="c-remote-editor" Width="700" data-backdrop="static" data-keyboard="false">
          <Name>Remote Profile</Name>
          <Template>templates/remote?goal=update</Template>
          <Commands>
            <Save data-replace-type="event"/>
            <Cancel/>
          </Commands>
        </Modal>
        <Modal Id="c-noremote-editor" Width="700" data-backdrop="static" data-keyboard="false">
          <Name>Remote Profile</Name>
          <Template>templates/remote?goal=create</Template>
          <Commands>
            <Save data-replace-type="event"><Label>Create</Label></Save>
            <Cancel/>
          </Commands>
        </Modal>
        <Modal Id="c-profile-editor" Width="700" data-backdrop="static" data-keyboard="false">
          <Name>Profile</Name>
          <Template>templates/profile?goal=update</Template>
          <Commands>
            <Save data-replace-type="event"/>
            <Cancel/>
          </Commands>
        </Modal>
        <Modal Id="c-nologin-editor" data-backdrop="static" data-keyboard="false">
          <Name>Creation of a user account</Name>
          <Template>templates/account?goal=create</Template>
          <Commands>
            <Save data-replace-type="event">
              <Label>Create</Label>
            </Save>
            <Cancel/>
          </Commands>
        </Modal>
        <Modal Id="c-login-editor" data-backdrop="static" data-keyboard="false">
          <Name>Modification to a user account</Name>
          <Template>templates/account?goal=update</Template>
          <Commands>
            <LeftSide>
              <Password>New password</Password>
            </LeftSide>
            <Delete>
              <Confirm>Are you sure you want to withdraw access to the application to that user ? If you want to reestablish it later you will have to create a new login.</Confirm>
            </Delete>
            <Save data-replace-type="event">
              <Label>Change</Label>
            </Save>
            <Cancel/>
          </Commands>
        </Modal>
        {
        if ($user = 'admin') then
          <Modal Id="c-params-editor" Width="800" data-backdrop="static" data-keyboard="false">
            <Name>Application parameters</Name>
            <Template>management/params?goal=update</Template>
            <Commands>
              <Save/>
              <Cancel/>
            </Commands>
          </Modal>
        else
          ()
        }
        <!-- adapted from Coach Match -->
        <Modal Id="cm-update-person-editor" Width="800">
          <Name>Update person record</Name>
          <Template>templates/person?goal=update&amp;realms=1</Template>
          <Commands>
            <!-- <Delete/> FIXME: implement it if necessary -->
            <Save data-type="json" data-replace-type="event"/>
            <Cancel/>
          </Commands>
        </Modal>
        <Modal Id="cm-import-person-editor">
          <Name>Import coach from Coach Match</Name>
          <Template>templates/person?goal=create&amp;realms=1</Template>
          <Commands>
            <Save data-type="json" data-replace-type="event">
              <Label loc="action.import">Import</Label>
            </Save>
            <Cancel>
              <Label loc="action.cancel">Cancel</Label>
            </Cancel>
          </Commands>
        </Modal>
      </Modals>
    </Content>
  </Page>
