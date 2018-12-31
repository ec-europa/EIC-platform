xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Activity workflow controller that manages the display of an activity state and documents.
   Generates a display model to be transformed into the HTML UI by workflow.xsl implementing
   the Workflow, Tab, Drawer and Documents (i.e. accordion) widgets.

   NOTE:
   - localized workflow state name are part of the model (Dictionary) element and injected in workflow.xsl
     to avoid duplicating global-information.xml content into dictionary.xml

   TODO:
   - (improvement) upgrade annexes module / annexes editor to manage meta-data with an index.xml catalog

   DEPRECATED : REPLACED WITH workflow.xqm

   August 2013 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace activity = "http://platinn.ch/coaching/activity" at "../activities/activity.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "workflow.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Generates the list of annexes which have been attached to a given
   document/facet of a given Activity of a given Case.
   ======================================================================
:)
declare function local:gen-annexes( $lang as xs:string, $case as element(), $activity as element() )
{
  let $no := $activity/No/text()
  let $col-uri := concat(util:collection-name($case), '/docs/activities/', $no)
  return
    <Annexes Collection="{$col-uri}">
      {
      if (xdb:collection-available($col-uri)) then
        for $f in xdb:get-child-resources($col-uri)
        let $item := $activity//Appendix[File eq $f]
        let $canDelete := access:check-appendix-delete($item)
        return
          workflow:gen-annexe-for-viewing($lang, $item, $f, $no, $col-uri, $canDelete)
      else
        ()
      }
    </Annexes>
};

(: ======================================================================
   Generates model data to show the workflow bar from Activity records
   Status may be a step or a state
   ======================================================================
:)
declare function local:gen-workflow-steps( $activity as element(), $lang as xs:string ) {
  let $current-status := $activity/StatusHistory/CurrentStatusRef
  return
  <Workflow Name="Case">
    {for $s in fn:doc ('/db/sites/cctracker/global-information/global-information.xml')/GlobalInformation/Description[@Lang = $lang]/ActivityStatus/Status/Id
    return
      if ($s = ("7","8","9")) then (: state :)
        if ($s = $current-status) then
          <Step Display="state" Status="current" StartDate="{display:gen-display-date($activity/StatusHistory/Status[ValueRef = $s]/Date, $lang)}" Num="{$s}"/>
        else
          <Step Display="state" StartDate="{display:gen-display-date($activity/StatusHistory/Status[ValueRef = $s]/Date, $lang)}" Num="{$s}"/>
      else (: step :)
        if ($s = $current-status) then
          <Step Display='step' Status="current" StartDate="{display:gen-display-date($activity/StatusHistory/Status[ValueRef = $s]/Date, $lang)}" Num="{$s}"/>
        else
          <Step Display='step' StartDate="{display:gen-display-date($activity/StatusHistory/Status[ValueRef = $s]/Date, $lang)}" Num="{$s}">
            { if ($s = ("7","8","9")) then attribute { 'Display'} { 'state' } else () }
          </Step>
    }
  </Workflow>
};

(: ======================================================================
   Generates model data to display the workflow editor accordion from Activity records
   together with the associated action buttons for each document/facet.
   FIXME: generates document list from workflow state and database content !
   FIXME: generate <ChangeStatus/> on latest document iff user is allowed to do it !
   ======================================================================
:)
declare function local:gen-information( $case-no as xs:string, $case as element(), $activity as element(), $lang as xs:string ) {
  let $current-status := number($activity/StatusHistory/CurrentStatusRef)
  return 
    <Accordion>
      {(
      
      <Document Status="current" Id="case">
        <Name loc="workflow.title.case">Cas concerné</Name>
        <Resource>../../../{$case-no}.blend</Resource>
        <Template>../../../templates/case?goal=read</Template>
        <Actions>
          {
          if (access:check-case-update($case)) then
            <Edit>
              <Resource>../../../{$case-no}.xml?goal=update&amp;from=workflow</Resource>
              <Template>../../../templates/case?goal=update</Template>
            </Edit>
          else
            ()
          }
        </Actions>
      </Document>,
      
      <Document Status="current" Id="foundr">
        <Name loc="workflow.title.fundingRequest">Demande de financement activité</Name>
        <Resource>funding-request.blend</Resource>
        <Template>../../../templates/funding-request?goal=read</Template>
        {
        if ($current-status = 1) then
          <Actions>
            {
            if (access:check-status-change($activity)) then
              <ChangeStatus Status="1" TargetEditor="c-alert"/>
            else 
              ()
            }
            {
            if (access:check-funding-request-update($case, $activity))  then (
              <Edit>
                <Resource>funding-request.xml?goal=update</Resource>
                <Template>../../../templates/funding-request?goal=update</Template>
              </Edit>,
              <Delete/>
              )
            else
              ()
            }
          </Actions>
        else if ($current-status = 2) then
          if (access:check-funding-request-correct($case, $activity))  then
            <Actions>
              <Edit loc="action.correct">
                <Resource>funding-request.xml?goal=update</Resource>
                <Template>../../../templates/funding-request?goal=update</Template>
              </Edit>
            </Actions>
          else
            ()
        else
          ()
        }
      </Document>,
      
      if ($current-status >= 2) then (
        let $flag := $activity/StatusHistory/CurrentStatusRef/text() = '2'
        return
          <Document Status="current" Id="opinions">
            <Name loc="workflow.title.opinions">Avis et prises de position des responsables</Name>
            <Resource>opinions.xml</Resource> <!-- FIXME: no need for .blend so far -->
            <Template>../../../templates/opinions?goal=read{if ($flag) then '&amp;opinions=1' else ()}</Template>
            {
            if ($current-status = 2) then
              <Actions>
                {
                if (access:check-status-change($activity)) then
                  <ChangeStatus Status="2" TargetEditor="c-alert"/>
                else
                  ()
                }
              </Actions>
            else
              ()
            }
          </Document>
        )
      else
        (),
        
      if ($current-status >= 3) then
        <Document Status="current" Id="foundd">
          <Name loc="workflow.title.fundingDecision">Décision de financement</Name>
          <Resource>funding-decision.xml</Resource> <!-- FIXME: no need for .blend so far -->
          <Template>../../../templates/funding-decision?goal=read</Template>
          {
          if ($current-status = 3) then
            <Actions>
              {
              if (access:check-status-change($activity)) then
                <ChangeStatus Status="3" TargetEditor="c-alert"/>
              else
                ()
              }
              {
              if (access:check-funding-decision-update()) then
                <Edit>
                  <Resource>funding-decision.xml?goal=update</Resource>
                  <Template>../../../templates/funding-decision?goal=update</Template>
                </Edit>
              else
                ()
              }
            </Actions>
          else
            ()
          }
        </Document>
      else
        (),
        
      if (($current-status >= 4) and ($current-status != 7)) then
      (
        let $writable := access:check-logbook-update($activity)
        return
          <Document Status="current" Id="logbook">
            <Name loc="workflow.title.journal">Suivi des coûts</Name>
            {
            if ($current-status = 4) then
              <Actions>
                {
                if ($writable) then (
                  <Drawer Command="edit" loc="action.add.logbookItem" AppenderId="c-logbook-list">
                    <Controller>logbook</Controller>
                    <Template>../../../templates/logbook-item?goal=create</Template>
                  </Drawer>
                  )
                else
                  ()
                }
              </Actions>
            else
              ()
            }
            <Content>
              { 
              let $del := $writable and ($current-status = 4)
              return 
                local:gen-logbook-items($lang, $activity, $del) 
              }
            </Content>
          </Document>,
        
        <Document Status="current" Id="final-report">
          <Name loc="workflow.title.finalReport">Rapport final</Name>
          <Resource>final-report.xml?goal=read</Resource> <!-- FIXME: no need for .blend so far -->
          <Template>../../../templates/final-report?goal=read</Template>
          {
          if ($current-status = 4) then
            <Actions>
              {
              if (access:check-status-change($activity)) then
                <ChangeStatus Status="4" TargetEditor="c-alert"/>
              else
                ()
              }
              {
              if (access:check-final-report-update($activity)) then
                <Edit>
                  <Resource>final-report.xml?goal=update</Resource>
                  <Template>../../../templates/final-report?goal=update</Template>
                </Edit>
              else
                ()
              }
            </Actions>
          else
            ()
          }
        </Document>
      )
      else
        (),
        
      if ( ($current-status >= 5)  and ($current-status != 7)) then
        <Document Status="current" Id="final-report-approvement">
          <Name loc="workflow.title.finalReportValidation">Validation du rapport final</Name>
          <Resource>final-report-approvement.xml</Resource>
          <Template>../../../templates/final-report-approvement?goal=read</Template>
          {
          if ($current-status = 5) then
            <Actions>
              {
              if (access:check-status-change($activity)) then
                <ChangeStatus Status="5" TargetEditor="c-alert"/>
              else
                ()
              }
              {
              if (access:check-approvement-update($activity)) then
                <Edit>
                  <Resource>final-report-approvement.xml?goal=update</Resource> 
                  <Template>../../../templates/final-report-approvement?goal=update</Template>
                </Edit>
              else
                ()
              }
            </Actions>
          else
            ()
          }
        </Document>
      else
        ()
        
      )}
    </Accordion>
};

(: ======================================================================
   Special version of local:gen-information but for legacy activities
   ======================================================================
:)
declare function local:gen-legacy-information( $case-no as xs:string, $case as element(), $activity as element(), $lang as xs:string ) {
  let $current-status := number($activity/StatusHistory/CurrentStatusRef)
  return 
    <Accordion>
      {(
      
      <Document Status="current" Id="case">
        <Name loc="workflow.title.case">Cas concerné</Name>
        <Resource>../../../{$case-no}.blend</Resource>
        <Template>../../../templates/case?goal=read</Template>
        <Actions>
          {
          if (access:check-case-update($case)) then
            <Edit>
              <Resource>../../../{$case-no}.xml?goal=update&amp;from=workflow</Resource>
              <Template>../../../templates/case?goal=update</Template>
            </Edit>
          else
            ()
          }
        </Actions>
      </Document>,
      
      <Document Status="current" Id="foundr">
        <Name loc="workflow.title.fundingRequest">Demande de financement activité</Name>
        <Resource>funding-request.blend</Resource>
        <Template>../../../templates/funding-request?goal=read</Template>
        <Actions>
          <Edit loc="action.correct">
            <Resource>funding-request.xml?goal=update</Resource>
            <Template>../../../templates/funding-request?goal=update</Template>
          </Edit>
        </Actions>
      </Document>,
        
      if ($current-status >= 3) then
        <Document Status="current" Id="foundd">
          <Name loc="workflow.title.fundingDecision">Décision de financement</Name>
          <Resource>funding-decision.xml</Resource> <!-- FIXME: no need for .blend so far -->
          <Template>../../../templates/funding-decision?goal=read</Template>
          <Actions>
            <Edit loc="action.correct">
              <Resource>funding-decision.xml?goal=update</Resource>
              <Template>../../../templates/funding-decision?goal=update</Template>
            </Edit>
          </Actions>
        </Document>
      else
        (),
        
      if (($current-status >= 4) and ($current-status != 7)) then
        <Document Status="current" Id="final-report">
          <Name loc="workflow.title.finalReport">Rapport final</Name>
          <Resource>final-report.xml?goal=read</Resource> <!-- FIXME: no need for .blend so far -->
          <Template>../../../templates/final-report?goal=read</Template>
          <Actions>
            <Edit loc="action.correct">
              <Resource>final-report.xml?goal=update</Resource>
              <Template>../../../templates/final-report?goal=update</Template>
            </Edit>
          </Actions>
        </Document>
      else
        (),
        
      if ( ($current-status >= 5)  and ($current-status != 7)) then
        <Document Status="current" Id="final-report-approvement">
          <Name loc="workflow.title.finalReportValidation">Validation du rapport final</Name>
          <Resource>final-report-approvement.xml</Resource>
          <Template>../../../templates/final-report-approvement?goal=read</Template>
          <Actions>
            <Edit loc="action.correct">
              <Resource>final-report-approvement.xml?goal=update</Resource> 
              <Template>../../../templates/final-report-approvement?goal=update</Template>
            </Edit>
          </Actions>
        </Document>
      else
        ()
        
      )}
    </Accordion>
};

(: ======================================================================
   Generates the different sections which can be chosen to compose a report
   ======================================================================
:)
declare function local:gen-reports-model( $lang as xs:string, $activity as element() ) as element()*
{
  let $dico-keys := (
                    "reportsSection.fundingRequest.draft",
                    "reportsSection.fundingRequest.consulting",
                    "reportsSection.fundingRequest",
                    "reportsSection.position.inprogress",
                    "reportsSection.position",
                    "reportsSection.fundingDecision.inprogress",
                    "reportsSection.fundingDecision",
                    "reportsSection.finalReport.draft",
                    "reportsSection.finalReport.pending",
                    "reportsSection.finalReport",
                    "reportsSection.finalReportApprovement.pending",
                    "reportsSection.finalReportApprovement"
                    )
  let $current-status := number($activity/StatusHistory/CurrentStatusRef)
  let $keys :=  if ($current-status = 1 ) then
                  $dico-keys[1]
                else if ($current-status = 2) then 
                  $dico-keys[(2, 4)]
                else if ($current-status = 3) then 
                  $dico-keys[(3, 5, 6)]
                else if ($current-status = 4) then 
                  $dico-keys[(3, 5, 7, 8)]
                else if ($current-status = 5) then 
                  $dico-keys[(3, 5, 7, 9, 11)]
                else if ($current-status = 7) then 
                  $dico-keys[(3, 5, 7)]                  
                else
                  $dico-keys[(3, 5, 7, 10, 12)]
  let $vals := (1, 
                if ($current-status = 2) then 
                  2 
                else if ($current-status = 3) then 
                  (2, 3)
                else if ($current-status = 4) then 
                  (2, 3, 4)
                else if ($current-status = 7) then 
                  (2, 3)                  
                else if ($current-status > 4) then 
                  (2, 3, 4, 5)
                else
                  ()
                )
  return
    <Sections>
      <Values Count="{count($vals)}">{$vals}</Values>
      <Labels>{display:gen-reports-sections-selector($keys, $lang)}</Labels>
    </Sections>
};

(: ======================================================================
   Generates the list of alerts associated to an activity
   ======================================================================
:)
declare function local:gen-alerts-list ($lang as xs:string,$activity as element() ) as element()*
{
  <AlertsList Id="c-alerts-list">
  {
    for $a in $activity/Alerts/Alert
    order by number($a/Id) descending
    return workflow:gen-alert-for-viewing($lang, $a, $activity/No)
  }
  </AlertsList>
};

(: ======================================================================
   Generates the list of other opinions associated to an activity
   FIXME: to be implemented !
   ======================================================================
:)
declare function local:gen-other-opinions ($lang as xs:string,$activity as element() ) as element()*
{
  <OtherOpinions Id="c-opinions-list">
  {
    for $o in $activity/Opinions/OtherOpinions/OtherOpinion
    return workflow:gen-otheropinion-for-viewing($lang,$o)
  }
  </OtherOpinions>
};

(: ======================================================================
   Generates the list of logbook items associated to an activity
   ======================================================================
:)
declare function local:gen-logbook-items ($lang as xs:string,$activity as element(), $canDelete as xs:boolean ) as element()*
{
  <Logbook Id="c-logbook-list">
  {
    for $lbi in $activity/Logbook/LogbookItem
    order by $lbi/Date descending
    return workflow:gen-logbook-item-for-viewing($lang,$lbi, $canDelete)
  }
  </Logbook>
  
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $case-no := tokenize($cmd/@trail, '/')[2]
let $activity-no := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
(: TODO: fine grain access control :)
return
  if ($m eq 'POST') then
    oppidum:throw-error("URI-NOT-FOUND", ())
  else
    if ($case and $activity) then
      <Display CaseNo="{$case-no}" ActivityNo="{$activity-no}">
        { $activity/@legacy }
        <ClientEnterprise>
          {$activity/FundingRequest/ClientEnterprise/Enterprise/Name}
        </ClientEnterprise>
        {$case/Title}
        { activity:gen-activity-for-viewing($activity, $lang) }
        { local:gen-workflow-steps($activity, $lang) }
        <Tabs>
          <Tab Id="activity">
            <Name loc="workflow.name.info">Information</Name>
            { 
            local:gen-information($case-no, $case, $activity, $lang) 
            }
          </Tab>
          <Tab Id="annexes">
            <Name loc="workflow.name.annexes">Annexes</Name>
            {
            if (access:check-appendix-upload($case, $activity)) then
              <Drawer Command="annex">
                <Title loc="workflow.title.annexes">Documents annexes</Title>
              </Drawer>
            else
              <Heading>
                <Title loc="workflow.title.annexes">Documents annexes</Title>
              </Heading>
            }   
            { local:gen-annexes($lang, $case, $activity) }
          </Tab>
          <Tab Id="alerts">
            <Name loc="workflow.name.messages">Messages</Name>
            <Drawer Command="edit" loc="action.add.message" PrependerId="c-alerts-list">
              <Title loc="workflow.title.messages">Messages</Title>
              <Initialize>alerts?goal=init</Initialize>
              <Controller>alerts</Controller>
              <Template>../../../templates/spontaneous-alert?goal=create</Template>
            </Drawer>
            { local:gen-alerts-list($lang,$activity) }
          </Tab>
          <Tab Id="reports">
            <Name loc="workflow.name.reports">Rapports</Name>
            <Heading>
              <Title loc="workflow.title.reports">Génération du rapport</Title>
            </Heading>
            <Reports>
              { local:gen-reports-model($lang, $activity) }
            </Reports>
          </Tab>
          {
          if (access:check-print-contract())  then
            <Tab Id="contract">
              <Name loc="workflow.name.contract">Contrat</Name>
              <Heading>
                <Title loc="workflow.title.contract">Génération du contrat</Title>
              </Heading>
              <Contract/>
            </Tab>
          else
            ()
          }
        </Tabs>
        <Modals>
          <Modal Id="c-alert" Width="620px">
            <!-- FIXME: localize -->
            <Title>Envoyer un message</Title>
            <Legend>Le statut a été modifié avec succès, remplissez le formulaire et cliquez sur "Envoyer" pour envoyer un message aux destinataires de votre choix</Legend>
            <Editor>
              <Initialize>alerts?goal=init&amp;from=status</Initialize>
              <Controller>alerts?next=redirect</Controller>
              <Template>../../../templates/automatic-alert?goal=create</Template>
            </Editor>
          </Modal>
        </Modals>
        <Dictionary>
          { fn:doc('/db/sites/cctracker/global-information/global-information.xml')//Description[@Lang eq $lang]/ActivityStatus }
        </Dictionary>
      </Display>
    else
      oppidum:throw-error("URI-NOT-FOUND", ())
