xquery version "3.1";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Team overview page

   Shows team members on an Accordion

   NOTE: the cache is not really necessary since teams are expected 
   to be limited (a few persons)

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Generates an in-memory cache to speed up page rendering by reducing
   the amount of database lookup operations
   ======================================================================
:)
declare function local:gen-cache() as map() {
  map:put(
    display:gen-map-for('Functions', 'en'),
    'enterprise-scope',
    form:get-normative-selector-for('Functions')/Option[@Scope = "enterprise"]/Value/text()
  )
};

declare function local:get-accreditation ($name as xs:string, $function as xs:string, $cie-ref as xs:string, $profile as element()?) as xs:string? {
  if ($profile//Role[FunctionRef eq $function]/EnterpriseRef = $cie-ref) then
    $name
  else
    ()
};

(: ======================================================================
   Generates Document model to display member information inside Accordion
   NOTE: non optimized access:check-entity-permissions call
   ====================================================================== 
:)
declare function local:gen-member-tab ( 
  $member as element(),
  $cie-ref as xs:string, 
  $profile as element()?,
  $cache as map() ) as element() 
{
  <Document Id="team-member-{$member/Id}">
    <Name>
      {
      let $name := $member/Information/Name
      return
          if ($name) then concat($name/FirstName, ' ', $name/LastName) else "... edit member name"
      }
    </Name>
    {
      let $roles := if (empty($profile)) then () else custom:get-member-roles-for($profile, $cie-ref, $cache)
      return
        if (exists($member/Rejected)) then
          <SubTitle style="color:red">rejected on { display:gen-display-date($member/Rejected/@Date, 'en') }</SubTitle>
        else if (exists($roles)) then
          <SubTitle>
            {
            if (exists($profile/Blocked)) then
              attribute { 'style' } { 'color:red' }
            else
              (),
            concat(
              'accredited as ', display:gen-map-name-for('Functions', $roles, $cache),
              if (exists($profile/Blocked)) then 
                concat(' but blocked since ', display:gen-display-date($profile/Blocked/@Date, 'en'))
              else
                ()
              )
            }
          </SubTitle>
        else
          <SubTitle>not accredited yet</SubTitle>
    }
    <Resource>members/{$member/Id/text()}.xml?goal=read</Resource>
    <Template>../templates/team/member?goal=read</Template>
    <Actions>
      {
      if (access:check-entity-permissions('delete', 'Member', $member/ancestor::Enterprise, $member)) then
        <Delete>
          <Resource>members/{$member/Id/text()}/delete</Resource>
        </Delete>
      else
        (),
      if (access:check-tab-permissions('update', 'team-member', $member/ancestor::Enterprise, $member)) then 
        <Edit>
          <Resource>members/{$member/Id/text()}.xml?goal=read</Resource>
          <Template>../templates/team/member?goal=update</Template>
        </Edit>
      else
        ()
      }
    </Actions>
  </Document>
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $profile := user:get-user-profile()
let $id := string($cmd/resource/@name)
let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $id]
let $title := custom:gen-enterprise-title($enterprise)
let $access := access:get-entity-permissions('view', 'Team', $enterprise)
return
  if (local-name($access) eq 'allow') then
    let $is-an-investor := enterprise:is-a($enterprise, 'Investor')
    return
      <Page StartLevel="1" skin="fonts extensions accordion" ResourceName="{ $id }">
        <Window>{ $title } team</Window>
        <Model>
          <Navigation>
            <Mode>single</Mode>
            <Key>team</Key>
            <Resource>{ $id }</Resource>
            <Name>{ $title }</Name>
          </Navigation>
        </Model>
        <Content>
          <Drawer Id="add-member">
            <Title>Team composition</Title>
            { 
            if (empty($enterprise/Team/Members/Member)) then
              <SubTitle>The database currently does not contain any team member information</SubTitle>
            else
              <SubTitle>Click on a team member name to view his information</SubTitle>,
            if ($is-an-investor) then
              <Actions>
                <Edit>
                  <Label>Add an investor</Label>
                  <Controller>{ concat($cmd/resource/@name, '/investor') }</Controller>
                  <Template>../templates/team/member?goal=create</Template>
                </Edit>
              </Actions>
            else if ($is-an-investor and
                     access:check-entity-permissions('add', 'Investor', $enterprise)) then
               <Actions>
                 <Edit>
                   <Label>Add an investor</Label>
                   <Controller>{ concat($cmd/resource/@name, '/investor') }</Controller>
                   <Template>../templates/team/member?goal=create</Template>
                 </Edit>
               </Actions>
            else
              <Actions>
                {
                if (($enterprise/Settings/Teams eq 'DG') and
                    access:check-entity-permissions('add', 'DG', $enterprise)) then
                  <Edit>
                    <Label>Add an external (DG)</Label>
                    <Controller>{ concat($cmd/resource/@name, '/DG') }</Controller>
                    <Template>../templates/team/member?goal=create</Template>
                  </Edit>
                else
                  (),
                (: trick to add Unaffiliated users from EASME team page :)
                if ($enterprise/Id eq '1' and
                    access:check-entity-permissions('add', 'Unaffiliated', $enterprise)) then
                  (
                  <Edit>
                    <Label>Add unaffiliated User</Label>
                    <Controller>unaffiliated</Controller>
                    <Template>../templates/team/member?goal=create</Template>
                  </Edit>
                  )
                else
                  (),
                if (access:check-entity-permissions('add', 'Member', $enterprise)) then
                  <Edit>
                    <Label>Add a delegate</Label>
                    <Controller>{ concat($cmd/resource/@name, '/members') }</Controller>
                    <Template>../templates/team/member?goal=create</Template>
                  </Edit>
                else
                  (),
                if (access:check-entity-permissions('add', 'LEAR', $enterprise)) then
                  <Edit>
                    <Label>Add a LEAR</Label>
                    <Controller>{ concat($cmd/resource/@name, '/LEAR') }</Controller>
                    <Template>../templates/team/member?goal=create</Template>
                  </Edit>
                else
                  ()
                }
              </Actions>
            }
          </Drawer>
          {
          if (empty($enterprise/Team/Members/Member)) then
            ()
          else
            <Accordion>
            {
            let $persons := fn:collection($globals:persons-uri)
            let $cache := local:gen-cache()
            for $member in $enterprise/Team/Members/Member
            let $profile := if (exists($member/PersonRef)) then (: head for robustness :)
                              fn:head($persons//Person[Id eq $member/PersonRef]/UserProfile)
                            else
                              ()
            return
              local:gen-member-tab($member, $enterprise/Id, $profile, $cache)
            }
            </Accordion>
          }
        </Content>
      </Page>
  else
    $access
