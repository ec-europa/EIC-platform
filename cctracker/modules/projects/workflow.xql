xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Case workflow controller that manages the display of a case state and documents.
   Generates a display model to be transformed into the HTML UI by workflow.xsl implementing
   the Workflow, Tab, Drawer and Documents (i.e. accordion) widgets.

   NOTE:
   - localized workflow state name are part of the model (Dictionary) element and injected in workflow.xsl
     to avoid duplicating global-information.xml content into dictionary.xml

   January 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $pid := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
let $project := fn:collection($globals:projects-uri)//Project[Id eq $pid]
let $errors := access:pre-check-project($project, $m, (), ())
return
  if (empty($errors)) then
    <Display ResourceNo="{$pid}" Mode="workflow">
      <Cartouche>
        <Window>{ ($project/Information/Acronym, " project", display:gen-call-date($project)) }</Window>
        <Title>
          {
          workflow:gen-source($cmd/@mode, $project),
          workflow:gen-title($project)
          }
        </Title>
      </Cartouche>
      { workflow:gen-workflow-steps('Project', $project, $lang) }
      <Tabs>
        <Tab Id="project" class=" active">
          <Name loc="workflow.tab.project.info">Project</Name>
          { 
          workflow:gen-information('Project', $project, (), (), $lang) 
          }
        </Tab>
        <Tab Id="project-alerts" Counter="Alert" ExtraFeed="project-info">
          <Name loc="workflow.tab.project.messages">Project messages</Name>
          <Drawer Command="edit" loc="action.add.message" PrependerId="c-project-alerts-list" class="project">
            <Title loc="workflow.title.project.messages">Messages</Title>
            <Initialize>alerts?goal=init</Initialize>
            <Controller>alerts</Controller>
            <Template>../templates/notification?goal=create</Template>
          </Drawer>
          { workflow:gen-alerts-list('Project', 'c-project-alerts-list', $project, $pid, $lang) }
        </Tab>
        { workflow:gen-cases-tab($project, (), $lang) }
        <Tab Id="whois">
          <Name loc="workflow.tab.whois">Who is</Name>
          <Controller>{$pid}/whois</Controller>
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
          <Template>../templates/notification?goal=create&amp;auto=1</Template>
          <Commands>
            <Save data-replace-type="event"><Label loc="action.send">Send</Label></Save>
            <Cancel><Label loc="action.dontSend">Continue w/o sending</Label></Cancel>
          </Commands>
        </Modal>
        <Modal Id="c-alert-details" Width="700">
          <Name loc="term.alert">Alert messages</Name>
          <div class="ajax-res"/>
        </Modal>
      </Modals>
      <Dictionary>
        { fn:doc($globals:global-information-uri)//Description[@Lang eq $lang]/WorkflowStatus[@Name = 'Project'] }
      </Dictionary>
    </Display>
  else
    $errors
