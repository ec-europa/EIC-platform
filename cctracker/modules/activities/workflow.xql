xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Activity workflow controller that manages the display of an activity state and documents.
   Generates a display model to be transformed into the HTML UI by workflow.xsl implementing
   the Workflow, Tab, Drawer and Documents (i.e. accordion) widgets.
ge
   NOTE:
   - localized workflow state name are part of the model (Dictionary) element and injected in workflow.xsl
     to avoid duplicating global-information.xml content into dictionary.xml

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace activity = "http://platinn.ch/coaching/activity" at "../activities/activity.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $pid := tokenize($cmd/@trail,'/')[2]
let $case-no := tokenize($cmd/@trail,'/')[4]
let $activity-no := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
let $project := fn:collection($globals:projects-uri)//Project[Id eq $pid]
let $case := $project/Cases/Case[No eq $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
let $errors := access:pre-check-activity($project, $case, $activity, $m, (), ())
return
  if (empty($errors)) then
    <Display ResourceNo="{$activity-no}" Mode="workflow">
      <Cartouche>
        <Window>{ concat($project/Information/Acronym, " activity", display:gen-call-date($project)) }</Window>
        <Title LinkToCase="{ $case/No }">
          {
          workflow:gen-source($cmd/@mode, $project),
          workflow:gen-title($project)
          }
        </Title>
        <Subtitle>{ workflow:gen-subtitle($case) }</Subtitle>
      </Cartouche>
      { workflow:gen-workflow-steps('Activity', $activity, $lang) }
      <Tabs>
        <Tab Id="project" Link="../../../../{$project/Id}">
          <Name loc="workflow.tab.project.info">Project</Name>
        </Tab>
        <Tab Id="project-alerts" Counter="Alert" ExtraFeed="case-init">
          <Name loc="workflow.tab.project.messages">Project messages</Name>
          <Heading class="project">
            <Title loc="workflow.title.project.messages">Messages</Title>
          </Heading> 
          { workflow:gen-alerts-list('Project', 'c-project-alerts-list', $project, '../../..', $lang) }
        </Tab>
        <Tab Id="case" Link="../../{$case/No}">
          <Name loc="workflow.tab.case.info">Case</Name>
          <Legend>Click on Case title at the top to return Case workflow view</Legend>
        </Tab>
        <Tab Id="case-alerts" Counter="Alert" ExtraFeed="case-init">
          <Name loc="workflow.tab.case.messages">Case messages</Name>
          <Heading class="case">
            <Title loc="workflow.title.case.messages">Messages</Title>
          </Heading> 
          { workflow:gen-alerts-list('Case', 'c-case-alerts-list', $case, '../../', $lang) }
        </Tab>
        { workflow:gen-activities-tab($case, $activity, $lang) }
        { workflow:gen-new-activity-tab($project, $case, $activity, '../../') }
        <Tab Id="activity" class=" active">
          <Name loc="workflow.tab.activity.info">Activity information</Name>
          { 
          workflow:gen-information('Activity', $project, $case, $activity, $lang) 
          }
        </Tab>
        <Tab Id="activity-alerts" Counter="Alert" ExtraFeed="funding-request">
          <Name loc="workflow.tab.activity.messages">Coaching activity messages</Name>
          <Drawer Command="edit" loc="action.add.message" PrependerId="c-activity-alerts-list">
            <Title loc="workflow.title.activity.messages">Messages</Title>
            <Initialize>alerts?goal=init</Initialize>
            <Controller>alerts</Controller>
            <Template>../../../../../templates/notification?goal=create</Template>
          </Drawer>
          { workflow:gen-alerts-list('Activity', 'c-activity-alerts-list', $activity, '', $lang) }
        </Tab>
        <Tab Id="whois">
          <Name loc="workflow.tab.whois">Who is</Name>
          <Controller>{$activity-no}/whois</Controller>
          <Heading class="activity">
            <Title loc="workflow.title.activity.whois">Who is</Title>
          </Heading>
          <div class="ajax-res"/>
        </Tab>
      </Tabs>
      <Modals>
        <Modal Id="c-alert" Width="620" data-backdrop="static" data-keyboard="false">
          <Name>Send and archive an email message</Name>
          <Legend class="text-info">The status has been changed with success. You now have the possibility to send a notification message by e-mail to some stakeholders in relation with the new status. You may also choose not to send it.</Legend>
          <Initialize>alerts?goal=init&amp;from=status</Initialize>
          <Controller>alerts?next=redirect</Controller>
          <Template>../../../../../templates/notification?goal=create&amp;auto=1</Template>
          <Commands>
            <Save data-replace-type="event"><Label loc="action.send">Send</Label></Save>
            <Cancel><Label loc="action.dontSend">Continue w/o sending</Label></Cancel>
          </Commands>
        </Modal>
        <Modal Id="c-alert-details" Width="700">
          <Name loc="term.alert">Alert messages</Name>
        </Modal>
      </Modals>
      <Dictionary>
        { fn:doc($globals:global-information-uri)//Description[@Lang eq $lang]/WorkflowStatus[@Name = 'Activity'] }
      </Dictionary>
    </Display>
  else
    $errors
