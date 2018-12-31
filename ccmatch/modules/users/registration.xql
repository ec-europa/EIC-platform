xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Management single page application

   TODO: pass Resource / Controller to JSON (hard-coded in cm-management.js)

   September 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";
import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace cas = "http://oppidoc.com/ns/cas" at "../../lib/cas.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:can-register( $cmd as element(), $user as xs:string ) as xs:boolean {
  if (($user = fn:doc(oppidum:path-to-config('security.xml'))//Realm/Surrogate/User)
      and not(exists(cas:get-user-profile-in-realm(oppidum:get-current-user-realm())))) then
    true()
  else if (($cmd/@mode = ('dev')) and ($user eq 'guest')) then (: could be removed ??? :)
    true()
  else
    false()
};

(: DEPRECATED: Generates UUID first to be able to generate link to create user's login :)
let $cmd := oppidum:get-command()
let $user := xdb:get-current-user()
let $goal := request:get-parameter('goal', ())
return
  if ($goal eq 'merge')then (: pre-filling self-registration from EU login first access :)
    let $all := session:get-attribute('cas-res')
    (: TODO: (when available) don't set them to empty string because that prevents required=true to work
      <Name>
        <LastName>{ $all/lastname/text() }</LastName>
        <FirstName>{ $all/firstname/text() }</FirstName>
      </Name>
    :)
    return
      <Profile>
        <Information>
          <Contacts>
            <Email>{ $all/email/text() }</Email>
          </Contacts>
        </Information>
      </Profile>
  else if (local:can-register($cmd, $user)) then
    <Page StartLevel="2" skin="cm-management">
      <Window>Login creation</Window>
      <Content>
        <Tabs Id="cm-tabs">
          <Tab Id="cm-info-tab" class="active">
            <Name>Help</Name>
            <Title Level="1">How to create a new Coach Match user account ?</Title>
            <dl>
              <dt><b>Step 1</b></dt>
              <dd>click on the <i>Account Information</i> tab, then fill in your profile information and hit the <i>Create my profile</i> button when ready. Please check that your e-mail address matches the address used to authenticate through EU login.</dd>
            </dl>
          </Tab>
          <Tab Id="cm-user-tab">
            <Name>Account Information</Name>
            <Title Level="1">Create a new user account</Title>
            <Edit Id="cm-user-edit">
              <Name>Enter new user record</Name>
              {
              (: detects user first login from remote authentication to merge :)
              let $realm := oppidum:get-current-user-realm()
              let $merging := exists($realm) and not(cas:get-user-profile-in-realm($realm))
              let $goal := if ($merging) then 'merge' else 'create'
              return
                <Template>templates/coach/coach-registration?goal={$goal}</Template>
              }
              <Resource>registration.xml?goal=merge</Resource>
              <Commands W="12" L="0">
                <Save data-type="json" data-replace-type="event" data-validation-output="cm-user-edit-errors" data-validation-label="label">
                  <Resource>management/users</Resource>
                  <!--<TabControl data-insert-uuid="{$TOKEN}" data-insert-variable="Uuid" data-reload-controller="cm-nologin-edit">
                    <Disable/>
                    <Select>cm-nologin-tab</Select>
                  </TabControl>-->
                  <Label>Create my profile</Label>
                </Save>
                <!--<Delete data-controller="{$TOKEN}/delete" Role="secondary">
                  <Label>Cancel registration</Label>
                  <Disable/>
                </Delete>-->
              </Commands>
            </Edit>
          </Tab>
          <!--<Tab Id="cm-nologin-tab" State="invisible" Command="ow-open">
            <Name>Login Information</Name>
            <Title Level="1">Create a login</Title>
            <Edit Id="cm-nologin-edit">
              <Template When="deferred">templates/login?goal=create</Template>
              <Resource>management/accounts/{$TOKEN}?goal=create</Resource>
              <Commands W="12" L="0">
                <Save data-type="json" data-replace-type="event" data-validation-output="cm-nologin-edit-errors" data-validation-label="label">
                  <Label loc="action.add.account">Create Login</Label>
                </Save>
                <TabControl Role="secondary">
                  <Select>cm-user-tab</Select>
                  <Hide/>
                  <Label>Update account information</Label>
                  <ShowDelete>cm-user-tab</ShowDelete>
                </TabControl>
                <Delete data-controller="{$TOKEN}/delete" Role="secondary">
                  <Label>Delete my account</Label>
                </Delete>
              </Commands>
            </Edit>
          </Tab>-->
        </Tabs>
      </Content>
    </Page>
  else (: user logged on internal realm :)
    let $redir := oppidum:redirect(concat($cmd/@base-url, access:mapping-from-username(oppidum:get-current-user())))
    return 
      oppidum:add-error('CUSTOM', 'You are not allowed to register a new account', true())
