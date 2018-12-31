xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Management single page application

   TODO: pass Resource / Controller to JSON (hard-coded in cm-management.js)

   September 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $user := oppidum:get-current-user()
return
  <Page StartLevel="2" skin="cm-management">
    <Window>CM management</Window>
    <Content>
      <Verbatim>
        <p id="cm-mgt-busy" class="cm-busy" style="display:none;margin-left:400px" loc="term.loading">Loading...</p>
      </Verbatim>
      <Tabs>
        <Tab Id="cm-user-tab" class="active">
          <Name>Users</Name>
          <Title Level="1">Users management</Title>
          <Edit Id="cm-user-edit">
            <Template>templates/user?goal=update</Template>
            <Commands>
              <Button Id="cm-user-button">
                <Label>Search</Label>
              </Button>
              <Cancel>
                <Label loc="action.back">Back</Label>
                <Action>{$user}</Action>
              </Cancel>
                <Create TargetEditor="cm-create-person-editor" style="float:right">
                <Controller>management/users</Controller>
                <Label loc="action.add.person">Add</Label>
              </Create>
            </Commands>
          </Edit>
          <Management-UserResults/>
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
        <Tab Id="cm-login">
          <Name>Login</Name>
          <Controller>management/login</Controller>
        </Tab>
        <Tab Id="cm-histories">
          <Name>Histories</Name>
          <Controller>management/histories</Controller>
        </Tab>
      </Tabs>
      <Modals>
        <Edit Id="cm-update-person-editor" Width="800">
          <Name>Update user record</Name>
          <!-- <Template>templates/coach/contact?goal=update</Template> -->
          <Resource>management/users/$_</Resource>
          <Commands>
            <Save>
              <Label loc="action.save">Save</Label>
            </Save>
            <Cancel>
              <Label loc="action.close">Close</Label>
            </Cancel>
            <Aside>
              <Delete>
                <Label loc="action.delete.person">Delete</Label>
              </Delete>
            </Aside>
          </Commands>
        </Edit>
        <Edit Id="cm-create-person-editor">
          <Name>Enter new user record</Name>
          <Template>templates/coach/contact?goal=create</Template>
          <Commands>
            <Save>
              <Label loc="action.create">Add</Label>
            </Save>
            <Cancel>
              <Label loc="action.cancel">Cancel</Label>
            </Cancel>
          </Commands>
        </Edit>
        <Edit Id="cm-create-account-editor" Width="800">
          <Name>Enter user account information</Name>
          <Template>templates/account?goal=create</Template>
          <Controller>accounts/accounts</Controller>
          <Commands>
            <Save>
              <Label loc="action.add.account">Add</Label>
            </Save>
            <Cancel>
              <Label loc="action.close">Close</Label>
            </Cancel>
          </Commands>
        </Edit>
        <Edit Id="cm-update-account-editor" Width="800">
          <Name>Edit user account information</Name>
          <Template>templates/account?goal=update</Template>
          <Resource>management/accounts/$_</Resource>
          <Commands>
            <Delete>
              <Label loc="action.delete.account">Delete</Label>
              <Confirm>Are you sure you want to withdraw access to the application to that user ? If you want to reestablish it later you will have to create a new login ?</Confirm>
            </Delete>
            <Save>
              <Label loc="action.update.account">Update</Label>
            </Save>
            <Cancel>
              <Label loc="action.close">Close</Label>
            </Cancel>
            <Aside>
              <Password>
                <Label>New password</Label>
              </Password>
            </Aside>
          </Commands>
        </Edit>
      </Modals>
    </Content>
  </Page>
