xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Coach profile view construction for reading and editing

   TODO:
   - check access control (admin-system can see anyone, coach can see only himself)
   - generate Performance widget from cc20-cctracker feed
   - when saving host contact persons force a reload afterwards

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace xhtml="http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace epilogue = "http://oppidoc.com/oppidum/epilogue" at "../../../oppidum/lib/epilogue.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: TODO: share with home.xql, store in config/profile.xml :)
declare variable $local:config := 
  <Facets>
    <Facet Name="contact" Elements="Information" MaxScore="11"/>
    <Facet Name="experiences" Elements="Knowledge" Skills="LifeCycleContexts DomainActivities TargetedMarkets Services" Prefix="Rating" MaxScore="148"/>
    <Facet Name="competences" Skills="CaseImpacts" Prefix="Rating" MaxScore="27"/>
  </Facets>;

(: ======================================================================
   DEPRECATED : replace with last-modificaiton date
   ====================================================================== 
:)
declare function local:get-completion-score ($person as element()?, $facet as xs:string ) {
  let $model := $local:config/Facet[@Name eq $facet]
  let $done := 
    sum(
      for $e in tokenize($model/@Elements, ' ')
      return count($person/*[local-name(.) eq $e ]//*[count(*) eq 0][. ne ''])
    ) 
    +
    sum(
      for $s in tokenize($model/@Skills, ' ')
      return count($person/Skills[@For eq $s]//Skill[. ne ''])
    )
    let $max := xs:integer($model/@MaxScore)
  return
    if ($model/@MaxScore > 0) then 
      round (($done div $max) * 100)
    else
        100
};

declare function local:gen-user-roles( $person as element() ) as xs:string {
  if (empty($person/UserProfile//FunctionRef)) then
    "You currently does not have any role"
  else
    concat("You are registered as ",
      string-join(
        for $ref in $person/UserProfile//FunctionRef/text()
        let $def := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']/Functions/Function[Id = $ref]
        return
          $def/Name,
        " and "
        )
    )
};

(: ======================================================================
   Adds 'cm-coaches' skin for host managers and admin system
   ====================================================================== 
:)
declare function local:more-skin( $groups as xs:string*, $managed as xs:string*, $reflective as xs:boolean ) {
  if ($groups = 'admin-system' or not(empty($managed))) then
    ' cm-coaches stats C3'
  else
    ''
};

(: MAIN ENTRY POINT :)
let $cmd := request:get-attribute('oppidum.command')
let $user := oppidum:get-current-user()
let $token := tokenize($cmd/@trail, '/')[1]
let $groups := oppidum:get-current-user-groups()
let $person := access:get-person($token, $user, $groups)
let $userid := string($person/Id)
let $managed := access:get-managed-hosts($person)
return
  if (local-name($person) ne 'error') then
    let $name := display:gen-person-name($person, 'en')
    let $reflective := $user = ($person/UserProfile/Username, $person/UserProfile/Remote)
    let $a-coach := access:has-role($person, 'coach')
    let $self-suffix := if ($reflective) then '.self' else ()
    return
      <Page StartLevel="2" skin="editor { local:more-skin($groups, $managed, $reflective) }">
        <Window>CM dashboard of {$name}</Window>
        <XTHead>
          <Import Mesh="account-availabilities" Component="t_Coaching" Suffix="ava"/>
          <Import Mesh="account-visibilities" Component="t_Visibility" Suffix="vis"/>
          <Import Mesh="host-account" Component="t_HostAccount" Suffix="host"/>
        </XTHead>
        <!-- *************************************** -->
        <!-- Top command menu with 'ow-switch' logic -->
        <!-- *************************************** -->
        <Commands Command="ow-switch" data-variable="tab" data-event-source="cm-tabs" data-event-type="ow-switch">
          {
          if ($groups = 'admin-system' or not(empty($managed))) then
            for $host-def in fn:collection($globals:global-info-uri)//Selector[@Name = "Hosts"]/Option[not(NoShow)]
            let $host := fn:collection($globals:hosts-uri)//Host[Id = $host-def/Id/text()]
            where $host-def/Id/text() = $managed or $groups = 'admin-system'
            return
              <Menu data-meet-tab="{$host/Id/text()}-persons">
                <Save Target="cm-host-{$host/Id/text()}-persons-edit" data-replace-type="all">
                  <Label>Save Contacts</Label>
                </Save>
                <Load Target="cm-host-{$host/Id/text()}-persons-edit">
                  <Label>Reload</Label>
                </Load>
              </Menu>
          else
            (),
          <Menu data-meet-tab="contact">
            <Save Target="cm-contact-edit" data-replace-type="all" data-replace-target="cm-contact-update" data-validation-output="cm-contact-edit-errors" data-validation-label="label">
              <Label>Save Contact</Label>
            </Save>
            <Load Target="cm-contact-edit">
              <Label>Cancel</Label>
            </Load>
          </Menu>,
          <Menu data-meet-tab="experiences">
            <Save Target="cm-experiences-edit" data-replace-type="all" data-replace-target="cm-experiences-update" data-validation-output="cm-experiences-edit-errors">
              <Label>Save Experiences</Label>
            </Save>
            <Load Target="cm-experiences-edit">
              <Label>Cancel</Label>
            </Load>
          </Menu>,
          <Menu data-meet-tab="competences">
            <Save Target="cm-competences-edit" data-replace-type="all" data-replace-target="cm-competences-update" data-validation-output="cm-competences-edit-errors">
              <Label>Save Competences</Label>
            </Save>
            <Load Target="cm-competences-edit">
              <Label>Cancel</Label>
            </Load>
          </Menu>
        }
        </Commands>
        <Content>
          <Tabs Id="cm-tabs">
            <!-- ******** -->
            <!-- Home tab -->
            <!-- ******** -->
            <TabBox>
              <Tab Id="cm-home-tab" class="active" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="home">
                <Name>Home</Name>
                <Title Level="1">Dashboard of {$name}</Title>
                <Verbatim>
                  {
                    if (count($person//WorkingRankRef[text() = '1']) eq 0) then
                      <xhtml:p style="font-size:120%" loc="home.nocoaching.title{$self-suffix}">...</xhtml:p>
                    else
                      <xhtml:p style="font-size:120%">
                        <xhtml:span loc="home.coaching.title{$self-suffix}">...</xhtml:span>
                        <xhtml:b>
                        {
                        for $host in fn:collection($globals:global-info-uri)//Description[@Lang = 'en']/Selector[@Name = 'Hosts']/Option[not(NoShow)]
                        let $h := $person//Host[string(@For) = $host/Id/text()][WorkingRankRef/text() = '1']
                        return
                          concat(
                            if ($h) then
                              if ($h is $person//Host[1]) then
                                concat($host/Name/text(), ' coach')
                              else 
                                concat('; ', $host/Name/text(), ' coach')
                            else (),
                            if ($h/ContactRef) then
                              concat(' (your contact is ', display:gen-person-name-for-ref($h/ContactRef/text() ,'en'), ')')
                            else ())
                        }
                        </xhtml:b>
                      </xhtml:p>,
                      if ($groups = 'admin-system') then
                        if ($reflective) then 
                          <xhtml:p style="font-size:120%">You are registered as host account manager</xhtml:p>
                        else
                          <xhtml:p style="color:red">You can view this profile because you are registered as a host account manager, please be careful !</xhtml:p>
                      else
                        ()
                  }
                  <xhtml:hr class="a-separator"/>
                  <div style="display:flex; align-items: center" xmlns="http://www.w3.org/1999/xhtml">
                    <div style="flex: 0 0 45%; padding: 0 15px 0 15px;">
                      <Title style="text-align:center" Level="3" loc="home.informations.title{$self-suffix}">Last activities</Title>
                    </div>
                    {
                    if ($reflective) then 
                      <div style="flex: 1; padding: 0 15px 0 15px;">
                        <Title style="text-align:center" Level="3" loc="home.handbooks.title">Handbooks</Title>
                      </div>
                    else
                      ()
                    }
                  </div>
                  <div style="display:flex; align-items: flex-start" xmlns="http://www.w3.org/1999/xhtml">
                    <div style="flex: 0 0 45%; padding: 0 15px 0 15px;">
                      {
                        if ($person//Logs) then
                          display:gen-all-log-message($person, 5)
                        else
                          <p><i><Text loc="home.informations.void">Nothing to report so far</Text></i></p>
                      }
                    </div>
                    {
                    if ($reflective) then 
                      <div style="flex: 1; padding: 0 15px 0 15px;">
                        {
                          let $base := string($cmd/@base-url)
                          return
                            <ul>
                              <li><a href="{$base}tools/cc20-bi-roadmap-tool.xlsx" target="_blank">BI Roadmap Tool (<i>excel</i>)</a></li>
                              <li><a href="{$base}tools/cc20-bi-roadmap-handbook" target="_blank">BI Roadmap Methodology</a></li>
                              <li><a href="{$base}tools/cc20-business-architecture-slides.pptx" target="_blank">Business Architecture Support (<i>power point</i>)</a></li>
                              <li><a href="{$base}tools/cc20-macro-design-slides.pptx" target="_blank">Macro Design Support (<i>power point</i>)</a></li>
                              <li><a href="{$base}tools/cc20-strategy-organisation-handbook" target="_blank">Strategy &amp; Organisation Methodology</a></li>
                              <li><a href="{$base}tools/cc20-bi-segmentation-tool.xlsx" target="_blank">BI Segmentation Tool (<i>excel</i>)</a></li>
                              <li><a href="{$base}tools/cc20-bi-customer-needs-analysis-tool.xlsx" target="_blank">BI Customer Needs Analysis Tool (<i>excel</i>)</a></li>
                              <li><a href="{$base}tools/cc20-segmentation-customer-needs-slides.pptx" target="_blank">Segmentation &amp; Customer Needs Support (<i>power point</i>)</a></li>
                              <li><a href="{$base}tools/cc20-segmentation-handbook" target="_blank">Segmentation Methodology</a></li>
                            </ul>
                        }
                      </div>
                    else
                      ()
                    }
                  </div>
                </Verbatim>
              </Tab>
            </TabBox>
            <TabBox>
              <TabGroup>
                <Name>Coach profile</Name>
                <!-- **************** -->
                <!-- Contact formular -->
                <!-- **************** -->
                <Tab Id="cm-contact-tab" Command="ow-open" data-target-ui="cm-contact-menu" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="contact">
                  <Name>Contact</Name>
                  <Title Level="1">Information record of {$name}</Title>
                  <Text Id="cm-contact-update">{ display:gen-log-message-for($person, 'contact') } <Hint data-placement="right">Do not forget to click on "Save Contact" button at the top if you make any change to your contact information</Hint></Text>
                  <Edit Id="cm-contact-edit">
                    <Template When="deferred">{concat('templates/coach/contact?goal=update&amp;user=', $token, if ($groups = 'admin-system' or not(empty($managed))) then '&amp;realms=1' else '') }</Template>
                    <Resource>{$token}/profile/contact.xml</Resource>
                  </Edit>
                </Tab>
                <!-- ******************** -->
                <!-- Experiences formular -->
                <!-- ******************** -->
                <Tab Id="cm-experiences-tab" Command="ow-open" data-target-ui="cm-experiences-menu" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="experiences">
                  <Name>Experiences</Name>
                  <Title Level="1">Experiences of {$name}</Title>
                  <Text Id="cm-experiences-update">{ display:gen-log-message-for($person, 'experiences') } <Hint data-placement="right">Do not forget to click on "Save Experiences" button at the top if you make any change to your experiences</Hint></Text>
                  <Edit Id="cm-experiences-edit">
                    <Template When="deferred">templates/coach/experiences?goal=update&amp;user={$token}</Template>
                    <Resource>{$token}/profile/experiences.xml</Resource>
                  </Edit>
                </Tab>
                <!-- ******************** -->
                <!-- Competences formular -->
                <!-- ******************** -->
                <Tab Id="cm-competences-tab" Command="ow-open" data-target-ui="cm-competences-menu" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="competences">
                  <Name>Competences</Name>
                  <Title Level="1">Competences of {$name}</Title>
                  <Text Id="cm-competences-update">{ display:gen-log-message-for($person, 'competences') } <Hint data-placement="right">Do not forget to click on "Save Competences" button at the top if you make any change to your competences</Hint></Text>
                  <Edit Id="cm-competences-edit">
                    <Template When="deferred">templates/coach/competences?goal=update</Template>
                    <Resource>{$token}/profile/competences.xml</Resource>
                  </Edit>
                </Tab>
                <!-- ************************* -->
                <!-- Acceptance application -->
                <!-- ************************* -->
                <Tab Id="cm-acceptances-tab" Command="ow-open" data-target-ui="cm-acceptances-menu" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="acceptances">
                  <Name>Acceptances</Name>
                  <Title Level="1">Coach application of {$name}</Title>
                  <Text>If your coach profile is completed, you can submit your application to host organisation(s). Select the host organisation and submit your application. The host organisation will decide about your acceptance.</Text>
                  <Acceptances UID="{$userid}">
                    {
                    for $opt in fn:collection($globals:global-info-uri)//Description[@Lang eq 'en']/Selector[@Name eq "Hosts"]/Option[not(NoShow)]
                    let $cur-status := $person/Hosts/Host[@For eq $opt/Id]/AccreditationRef
                    let $ts := string($cur-status/@Date)
                    return
                      <Host For="{$opt/Id}">
                        {
                        $opt/Name,
                        $cur-status,
                        if ($cur-status) then
                          <Status>{ display:gen-name-for('Acceptances', $cur-status, 'en') } on { display:gen-display-date($ts,'en') } at { substring($ts, 12, 2) }:{ substring($ts, 15, 2) }</Status>
                        else
                          ()
                        }
                      </Host>
                    }
                  </Acceptances>
                 </Tab>
              </TabGroup>
              <!-- ************************** -->
              <!-- Coach preferences formular -->
              <!-- ************************** -->
              <Tab Id="cm-account-tab" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="account">
                <Name>Coach account</Name>
                <Title Level="1">Coach account of {$name}</Title>
                <Text Id="cm-account-availabilities-update">{ display:gen-log-message-for($person, 'availabilities') }</Text>
                <Edit Id="cm-account-availabilities-edit">
                  <Template When="inline" Tag="Coaching" TypeName="t_Coaching_ava"/>
                  <Resource>{$token}/profile/availabilities.xml</Resource>
                  <Commands W="8" style="margin-left:0;margin-top:10px;text-align:right">
                    <Save data-replace-type="all" data-replace-target="cm-account-availabilities-update">
                      <Label loc="action.save">Save</Label>
                    </Save>
                  </Commands>
                </Edit>
                <hr class="a-separator"/>
                <Text Id="cm-account-visibilities-update">{ display:gen-log-message-for($person, 'visibilities') }</Text>
                <Edit Id="cm-account-visibilities-edit">
                  <Template When="inline" Tag="Visibility" TypeName="t_Visibility_vis"/>
                  <Resource>{$token}/profile/visibilities.xml</Resource>
                  <Commands W="8" style="margin-left:0;margin-top:10px;text-align:right">
                    <Save data-replace-type="all" data-replace-target="cm-account-visibilities-update">
                      <Label loc="action.save" style="float:right">Save</Label>
                    </Save>
                  </Commands>
                </Edit>
                <hr class="a-separator"/>
                <Edit >
                  <Title Level="3">Remove your profile of Coach Match</Title>
                  <Text>With the removal of your coach profile from CoachMatch, you will not figure any more as a coach in the system. All links to your host organisations you are eventually accepted will be deleted. You also will lose your login.</Text>
                  <Commands W="8" style="margin-left:0;margin-top:10px;text-align:right">
                    <Delete data-controller="{$userid}/delete">
                      <Label>Yes, I remove my profile from Coach Match</Label>
                    </Delete>
                  </Commands>
                </Edit>
              </Tab>
              <!-- ****************** -->
              <!-- Coach performances -->
              <!-- ****************** -->
              <Tab Id="cm-performance-tab" >
                <Name>Coach performance</Name>
                <Title Level="1">Coaching performance of {$name}</Title>
                <Title Level="2">Average performance indicators</Title>
                <Title Level="3" Id="cm-performance-legend" style="margin-bottom:2em">Legend</Title>
                <Radar When="deferred" data-src="feeds/performance/{$token}" data-legend-target="cm-performance-legend" data-message-target="cm-performance-msg"/>
                <Performance-Table/>
                <Text Id="cm-performance-msg" class="text-warning" style="display:none"/>
              </Tab>
            </TabBox>
            <!-- ************ -->
            <!-- Coach search -->
            <!-- ************ -->
            { 
            if (access:check-user-can('search', 'Coach')) then
              <TabBox>
                <TabGroup>
                  <Name>Coach search</Name>
                  <Tab Id="cm-search-by-criteria-tab" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="criteria">
                    <Name>Search by criteria</Name>
                    <Title Level="1" style="margin-bottom:0">Search criteria 
                      <Hint data-placement="right" loc="search.criteria.hint">hint</Hint>
                    </Title>
                    <xhtml:p class="text-info" style="margin-top:0;font-size:16px">Search restricted to coaches who accepted being visible to other coaches on CoachMatch</xhtml:p>
                    <Edit Id="cm-criteria-edit">
                      <Template When="deferred">templates/criteria?goal=update</Template>
                      <Commands W="12" L="0" style="text-align:right">
                        <Save Target="cm-criteria-edit" data-src="suggest/criteria" data-type="json" data-replace-type="event" data-save-flags="disableOnSave silentErrors">
                          <Label>Search</Label>
                        </Save>
                      </Commands>
                    </Edit>
                    <xhtml:p id="cm-criteria-busy" class="cm-busy" style="display:none;margin-left:300px">Loading search by criteria results...</xhtml:p>
                    <Title Level="1">Results list</Title>
                    <Suggest-Filters Target="criteria"/>
                    <Suggest-Results Target="criteria"/>
                  </Tab>
                </TabGroup>
              </TabBox>
            else
              ()
            }
            {
            if ($groups = 'admin-system' or not(empty($managed))) then
              <TabBox>
                <TabGroup>
                  <Name>Host Account</Name>
                  {
                    for $host-def in fn:collection($globals:global-info-uri)//Selector[@Name = "Hosts"]/Option[not(NoShow)]
                    let $host := fn:collection($globals:hosts-uri)//Host[Id = $host-def/Id/text()]
                    where $host-def/Id/text() = $managed or $groups = 'admin-system'
                    return(
                      <Tab Id="cm-host-{$host/Id/text()}-info" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch">
                        <!-- ************ -->
                        <!-- Host account -->
                        <!-- ************ -->
                        <Name>{$host-def/Name/text()} organisation profile</Name>
                        <Title Level="1">Coach host organisation profile</Title>
                        <Title Level="2">{$host-def/Name/text()}</Title>
                        <Edit Id="cm-host-account-edit">
                          <Template When="inline" Tag="HostAccount" TypeName="t_HostAccount_host"/>
                          <Resource>hosts/{$host/Id/text()}/account.xml</Resource>
                        </Edit>
                        </Tab>,
                        <Tab Id="cm-host-{$host/Id/text()}-persons" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="{$host/Id/text()}-persons">
                          <!-- ******************** -->
                          <!-- Host contact persons -->
                          <!-- ******************** -->
                          <Name>{$host-def/Name/text()} contact persons</Name>
                          <Title Level="1">{$host-def/Name/text()} host</Title>
                          <Edit Id="cm-host-{$host/Id/text()}-persons-edit">
                            <Template When="deferred">templates/host/contact-persons?goal=update</Template>
                            <Resource>hosts/{$host-def/Id/text()}/contact-persons.xml</Resource>
                          </Edit>
                        </Tab>,
                        <Tab Id="cm-host-{$host/Id/text()}-coach-man" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="{$host/Id/text()}-coach-man">
                          <!-- ********************* -->
                          <!-- Host coach management -->
                          <!-- ********************* -->
                          <Name>{$host-def/Name/text()} coach management</Name>
                          <Title Level="1">{$host-def/Name/text()} host</Title>
                          <CoachManagement UID="{$userid}">
                            <HostRef>{ $host/Id/text() }</HostRef>
                          </CoachManagement>
                        </Tab>,
                        <Tab Id="cm-host-{$host/Id/text()}-coach-stats" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="{$host/Id/text()}-coach-stats" data-load-link="stats/coaches.raw?m=embed">
                          <!-- ********** -->
                          <!-- Statistics -->
                          <!-- ********** -->
                          <Name>Statistics</Name>
                        </Tab>
                      )
                      }
                </TabGroup>
                <TabGroup>
                  <Name>Users account</Name>
                  <Tab Id="cm-users-tab" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="users" data-open-link="management">
                    <!-- ************ -->
                    <!-- Manage users -->
                    <!-- ************ -->
                    <Name>Manage users</Name>
                  </Tab>
                  {
                  if ($groups = 'admin-system') then
                    <Tab Id="cm-feeds-tab" Command="ow-open" data-event-target="cm-tabs" data-event-type="ow-switch" data-event-name="feeds" data-open-link="console/feeds">
                      <!-- ************ -->
                      <!-- Manage users -->
                      <!-- ************ -->
                      <Name>Feeds console</Name>
                    </Tab>
                  else
                    ()
                  }
                </TabGroup>
              </TabBox>
            else
              ()
            }
          </Tabs>
          <Overlay>
            <Views>
              <!--
              <View Id="cm-evaluation-view" style="display:none">
                <Suggest-Evaluation>
                  <Suggest-Dimension Key="competence" Title="Competence">competence needs</Suggest-Dimension>
                  <Suggest-Dimension Key="experience" Title="SME context">SME context</Suggest-Dimension>
                </Suggest-Evaluation>
              </View>
              <View Id="cm-handout-view" style="display:none">
                <Suggest-Handout/>
              </View> 
              -->
              <View Id="cm-inspect-view" style="display:none">
                <Suggest-Inspect/>
              </View>
            </Views>
            <Modals>
              <Show Id="cm-coach-summary" Width="700px">
                <Title>Coach</Title>
              </Show>
              <Edit Id="cm-update-host-extra-editor" Width="800px">
                <Name>Extra</Name>
                <Commands>
                  <Save>
                    <Label loc="action.save">Save</Label>
                  </Save>
                  <Cancel>
                    <Label loc="action.close">Close</Label>
                  </Cancel>
                </Commands>
              </Edit>
            </Modals>
          </Overlay>
        </Content>
      </Page>
  else
    $person
