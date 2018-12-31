xquery version "3.1";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Main ranking lists editor controller (SMEIMKT-2348)

   Authors: 
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>
   - Stéphane Sire <s.sire@oppidoc.fr>

   November 2017
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../../xcm/modules/workflow/workflow.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../../xcm/modules/users/account.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace xt = "http://ns.inria.org/xtiger";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:enterprises := globals:collection('enterprises-uri');


declare function local:validate-submission( $submitted as element(), $goal as xs:string? ) {
  if ($goal eq 'reopen') then
    let $err1 := if (exists($submitted/SubmissionDate[. ne '']) 
                     and (xs:date($submitted/SubmissionDate) > current-date())) then 
                   () 
                 else 
                   oppidum:throw-error('CUSTOM', 'You must specify a new submission deadline in the future')
    return $err1
  else
    let $err1 := if (exists($submitted/PreDepartureDate[. ne ''])) then 
                   () 
                 else 
                   oppidum:throw-error('MISSING-PREDEPARTURE-DATE', ()) 
    let $err2 := if (empty($submitted/CCEmail) or matches($submitted/CCEmail, '^\s*$|^\w([-.]?\w)*@\w([-.]?\w)+\.[a-z]{2,}$' )) then
                   ()
                 else
                   oppidum:throw-error('INVALID-EMAIL', 'Send CC to')
    return ($err1, $err2)[1]
};

(: ======================================================================
   Return an Applicant model for the enterprise for the event
   ====================================================================== 
:)
declare function local:gen-applicant( $enterprise as element(), $event-def as element() ) as element() {
  let $tag := if ($event-def/Template/@ProjectKeyTag) then string($event-def/Template/@ProjectKeyTag) else 'Acronym'
  let $proj-id := $enterprise/Events/Event[Id = $event-def/Id]/Data/Application//*[local-name(.) eq $tag]/text()
  return
    <Applicant>
      <EnterpriseRef>{ $enterprise/Id/text() }</EnterpriseRef>
      <ProjectId Tag="{ $tag }">{ $proj-id }</ProjectId>
    </Applicant>
};

(: ======================================================================
   Return a list of Applicant(s) for the event from current DB content 
   ====================================================================== 
:)
declare function local:gen-applicants( $event-def as element() ) as element()* {
  for $ent in fn:collection('/db/sites/cockpit/enterprises')//Enterprise[Events/Event[ StatusHistory/CurrentStatusRef = '2' ]/Id = $event-def/Id ]
  return local:gen-applicant($ent, $event-def)
};

(: ======================================================================
   First time construction of the initial rankings lists
   Note: does not do anything for re-opened events since the ranking
   is visible before deadline
   MUST be called only after submission deadling for first iteration 
   because it creates MainList
   ====================================================================== 
:)
declare function local:lazy-initialize( $event-def as element() ) {
  if ($event-def/Rankings) then 
    ()
  else
    system:as-user(
      account:get-secret-user(), account:get-secret-password(),
      update insert
        <Rankings Iteration="cur">
          <Lists>
            <MainList>{ local:gen-applicants($event-def) }</MainList>
            <ReserveList/>
            <RejectList/>
          </Lists>
        </Rankings>
      into
        $event-def
    )
};

(: ======================================================================
   Return a copy of the Applicant list with frozen Status attribute
   ====================================================================== 
:)
declare function local:copy-and-freeze-list( $list as element() ) as element() {
  element { local-name($list) } {
    for $a in $list/Applicant
    return <Applicant Status="frozen">{ $a/* }</Applicant>
  }
};

(: ======================================================================
   Reopen submission workflow
   Make a new Rankings section initialized from the current one 
   Interpret mandatory <SubmissionDate>YYYY-MM-DD</SubmissionDate>
   and optional <DontReOpenRejected>on</DontReOpenRejected> flag in submitted data
   ====================================================================== 
:)
declare function local:reopen( $cmd as element(), $submitted as element(), $event-def as element() ) {
  let $rankings := $event-def/Rankings[@Iteration eq 'cur']
  let $final-rankings := $event-def/FinalRankings[@Iteration eq 'cur']
  let $lists := fn:head(($final-rankings, $rankings))/Lists
  return (
    (: Update event meta-data :)
    update value $event-def/Information/Application/To with string($submitted/SubmissionDate),
    (: Put back Rejected applicants into submission loop :)
    if (empty($submitted/DontReOpenRejected)) then
      for $a in $rankings/Lists/RejectList/Applicant
      let $application := globals:collection('enterprises-uri')//Enterprise[Id eq $a/EnterpriseRef]
      let $status := $application/Events/Event[Id eq $event-def/Id]/StatusHistory
      return (
        update value $status/PreviousStatusRef with string($status/CurrentStatusRef),
        update value $status/CurrentStatusRef with '1'
        )
    else
      (),
    (: Archive previous ranking lists iteration :)
    let $cur-iter := max(($event-def/Rankings/@Iteration[. ne 'cur'], 0)) + 1
    return (
      update value $rankings/@Iteration with $cur-iter,
      update value $final-rankings/@Iteration with $cur-iter
      ),
    (: Create new Rankings iteration :)
    update insert
      <Rankings Iteration="cur">
        { $rankings/PreDepartureDate }
        <Lists>
        {
        local:copy-and-freeze-list($lists/MainList),
        local:copy-and-freeze-list($lists/ReserveList),
        if (empty($submitted/DontReOpenRejected)) then
          <RejectList/>
        else
          local:copy-and-freeze-list($rankings/Lists/RejectList)
        }
        </Lists>
      </Rankings>
      into $event-def,
    ajax:report-success-redirect('WFS-RANKINGS-REOPENED', (), concat($cmd/@base-url, 'events/management'))
    )
};

(: ======================================================================
   Manage incremental ranking workflow transitions : Submitted, Confirmed,
   Finalized, and Reopen command. Manage lists Rankings // FinalRankings :
   - initial state: MainList, ReserveList (empty), RejectList (empty) // none
   - Submitted: MainList, ReserveList, RejectList // none
   - Confirmed: MainList, ReserveList, RejectList // MainList, ReserveList, CancelList (empty)
   - Finalized: MainList, ReserveList, RejectList // MainList, ReserveList, CancelList
   ====================================================================== 
:)
declare function local:save-rankings-and-advance( $cmd as element(), $submitted as element(), $event-def as element() ) {
  let $workflow := $event-def/Programme/@WorkflowId
  (: use latest iteration  :)
  let $latest-rankings := $event-def/Rankings[@Iteration eq 'cur']
  let $final-rankings := $event-def/FinalRankings[@Iteration eq 'cur']
  let $rankings := if (exists($final-rankings)) then $final-rankings else $latest-rankings
  let $last := if (exists($final-rankings)) then 'CancelList' else 'RejectList'
  let $advance := if (exists($final-rankings)) then 1 else 0
  let $lazy := exists($latest-rankings/Drafted) and empty($final-rankings)
  let $update := update replace $rankings with
    element { local-name($rankings) }
    {
      $rankings/@*,
      element
        { 
        if (not($latest-rankings/Drafted)) then 
          'Drafted'
        else
          'Confirmed'
        }
        {
          attribute CreatedByRef { user:get-current-person-id() },
          attribute TS { fn:current-dateTime() }
        },
      $rankings/Drafted,
      if (local-name($rankings) eq 'Rankings') then
        $submitted/PreDepartureDate
      else
        (),
      <Lists>
        {
        let $lists := ('MainList','ReserveList', $last)
        return
          for $l in $lists
          return
            element { $l } {
              for $item in $submitted//*[local-name(.) eq $l]/*
              (: change Applicant(s) workflow status and notifies - unless frozen :)
              let $ref := substring-after(local-name($item), 'A_')
              let $applicant := $rankings//Applicant[EnterpriseRef eq $ref]
              return
                (
                (: workflow transition and notification of confirmation or finalization
                   unless 'frozen' or finalization :)
                if (exists($latest-rankings/Drafted) and (exists($final-rankings) or (empty($applicant/@Status) or ($applicant/@Status ne 'frozen')))) then 
                  let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $ref]
                  let $event-application :=  $enterprise/Events/Event[Id = $event-def/Id]
                  let $notify-transition := 
                      (: next test is always false in FinalRankings because there is no RejectList  :)
                      if ($l eq 'RejectList') then
                        (: just to retrieve an eventual e-mail notification :)
                        workflow:get-transition-for($workflow, '2', '2')
                      else
                        (: pick up 1 of the different transitions from 3 to 4 in application.xml
                           Transition order imports to pick up correct e-mail notification if any !!! 
                           in FinalRankings it always picks up the 3rd one w/o e-mail notification :)
                        let $transition := workflow:get-transition-for($workflow, string(2 + $advance ), string(3 +  $advance))[ if ($final-rankings) then 3 else if ($l = 'MainList') then 1 else 2 ]
                        return
                          if (exists($transition)) then
                            let $errors := workflow:apply-transition($transition, $enterprise, $event-application)  
                            return
                             (: errors should be available in flash :)
                              if (empty($errors)) then $transition else ()
                          else
                            ()
                  return
                    if (exists($notify-transition)) then
                      (: send e-mail notification :)
                      let $enterprise-cc := <Enterprise>{ $submitted/CCEmail, $enterprise/* }</Enterprise>
                      return
                        workflow:apply-notification($workflow, <fakesuccess/>, $notify-transition, $enterprise-cc, $event-application)
                    else
                      ()
                else
                  (),
                (: pick up applicant from existing lists or create it :)
                if (exists($applicant)) then (: copies eveything, including @Status if any :)
                  $applicant
                else (: could happen during submission of Submit list for re-opened event  :)
                  let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $ref]
                  return local:gen-applicant($enterprise, $event-def)
                )[last()]
            }
        }
      </Lists>
    }
  return 
    (: upon confirmation we create new slots for final rankings :)
    let $init-final-rankings :=
      if ($lazy) then
        update insert 
          <FinalRankings Iteration="cur">
            <Lists>
              { $latest-rankings/Lists/(MainList|ReserveList) }
              <CancelList/>
            </Lists>
          </FinalRankings> following $latest-rankings
      else
        ()
    (: since confirmation update pre-departure briefing date :)
    let $update-pre-departure := 
      if ((local-name($rankings) ne 'Rankings') and ($submitted/PreDepartureDate ne $latest-rankings/PreDepartureDate)) then
        update value $latest-rankings/PreDepartureDate with $submitted/PreDepartureDate
      else
        ()
    return
      ajax:report-success-redirect('WFS-RANKINGS-SUBMITTED', (), concat($cmd/@base-url, 'events/management'))
};

(: ======================================================================
   Generate a sortable list widget from a $list of Applicant elements
   TODO: if cur-iter > 1 alors intégrer dynamiquement les dernières candidatures 
   ====================================================================== 
:)
declare function local:gen-list( $cmd as element(), $event-def as element(), $applicants as element()* ) as element()* {
  let $rankings := $event-def/Rankings[@Iteration eq 'cur']
  let $final-rankings := $event-def/FinalRankings[@Iteration eq 'cur']
  let $confirmed := exists($final-rankings) (:exists($rankings/Confirmed) and not($final-rankings/Confirmed):)
  return
    for $app in $applicants
    let $ent := $local:enterprises//Enterprise[Id = $app/EnterpriseRef]
    let $e := $ent/Information/ShortName/text()
    let $application := $ent//Event[Id eq $event-def/Id]
    let $tl := (string-length($e) > 22)
    (: highlight companies having not confirmed yet:)
    let $pending := if (($application/StatusHistory/CurrentStatusRef = '3' and ($confirmed or $app/@Status eq 'frozen')) or (($application/StatusHistory/CurrentStatusRef = '4' and empty($application/Data/Confirmation)))) then ' pending' else ()
    (: TODO: ne pas mettre highlite si Reject ??? :)
    (: highlight companies having confirmed :)
    let $confirmed := if ($application/StatusHistory/CurrentStatusRef = '4' and exists($application/Data/Confirmation)) then ' confirmed' else ()
    (: highlight frozen companies (i.e. imported from previous iteration) :)
    let $frozen := if ($app/@Status eq 'frozen') then ' frozen' else ()
    (: block companies that cannot be dragged and dropped :)
    let $sticky :=  ()(: if ($app/@Status eq 'frozen') then ' sticky' else ():)
    (: ... TODO: fixer uniquement les 'frozen' pendant Submit et Confirm list editing... :)
    return
      <xhtml:li data-id="{ $ent/Id }" style="margin-bottom:10px;max-width:200px" class="ranking-ui{$sticky}">
        <xhtml:div class="btn-group{$frozen}">
          <xhtml:a style="font-size:12px" class="btn btn-primary{$pending}{$confirmed}" data-toggle="dropdown" href="#">
          {
            if ($tl) then
              (: FIXME: use css hyphenation instead ? :)
              (replace(substring($e, 1, 22), '&amp;', 'and'),<xhtml:br/>,replace(substring($e, 23), '&amp;', 'and'))
            else
              replace($e, '&amp;', 'and')
          }
          { 
          let $evc := $app/EvaluatorComment
          return
            if ($evc/Score[. ne ''] or $evc/Comment/Text) then
              <xhtml:i class="fa fa-comments-o fa-fw"></xhtml:i>
            else
              ()
          }
          </xhtml:a>
          <xhtml:a class="btn btn-primary dropdown-toggle{$pending}{$confirmed}" data-toggle="dropdown" href="#"><xhtml:span class="fa fa-caret-down"/>{ if ($tl) then attribute style { 'padding-top:13px;padding-bottom:13px' } else () }</xhtml:a>
          <xhtml:ul class="dropdown-menu">
            <xhtml:li>
              <xhtml:a style="font-size:12px" target="_blank" href="{ concat($cmd/@base-url, 'events/', $app/EnterpriseRef, '/form/', $event-def/Id/text()) }"><xhtml:i class="fa fa-file fa-fw"/> View application</xhtml:a>
            </xhtml:li>
            <xhtml:li>
              <xhtml:a style="font-size:12px" href="#" data-event="{ concat($cmd/@base-url, 'events/', $app/EnterpriseRef, '/form/', $event-def/Id/text(), '/comments') }"><xhtml:i class="fa fa-plus-circle fa-fw"/> Score &amp; Comment</xhtml:a>
            </xhtml:li>
          </xhtml:ul>
        </xhtml:div>
        <xhtml:div style="display:none">
          <xt:use label="{ concat('A_', $app/EnterpriseRef) }" param="class=uneditable-input" types="input"/>
        </xhtml:div>
      </xhtml:li>
};

(: ======================================================================
   Return true if the event ranking can be sorted
   ====================================================================== 
:)
declare function local:sortable( $event-def as element() ) as xs:boolean {
  if (exists($event-def/FinalRankings[@Iteration eq 'cur']/Confirmed)) then (: final state reached :)
    false()
  else 
    let $rankings := $event-def/Rankings[@Iteration eq 'cur']
    return
      not(exists($rankings/Confirmed)) or (misc:net-working-days($rankings/Confirmed/@TS, current-dateTime()) ge 7)
};

(: ======================================================================
   Generate container and widget to display the list named $tag 
   of applicant from the event meta-data. Picks up
   ====================================================================== 
:)
declare function local:gen-component-list( $cmd as element(), $event-def as element(), $list as element(), $id as xs:string, $span as xs:string, $sortable as xs:boolean, $freeze as xs:boolean) as element() {
  let $tag := local-name($list)
  let $name := substring-before($tag, 'List')
  return
    <xt:component name="{$tag}">
      <xhtml:div id="index-{$id}" class="{$span}">
        <xhtml:h2>{ $name }</xhtml:h2>
        {
        if ($freeze and exists($list/Applicant[@Status eq 'frozen'])) then
          <xhtml:div>
            <xhtml:ul class="sort-container{if ($sortable) then ' well' else ()} freeze">
              { local:gen-list($cmd, $event-def, $list/Applicant[@Status eq 'frozen']) }
            </xhtml:ul>
          </xhtml:div>
        else
          ()
        }
        <xhtml:div>
          <xhtml:ul id="sortable-{$id}" class="sort-container{if ($sortable) then ' well' else ()}">
            { local:gen-list($cmd, $event-def, $list/Applicant[not($freeze) or (empty(@Status) or  @Status ne 'frozen')]) }
          </xhtml:ul>
        </xhtml:div>
      </xhtml:div>
    </xt:component>
};

(: ======================================================================
   Generates XTiger components with the lists for the ranking list editor
   Shows the list for the current status in the current iteration
   ====================================================================== 
:)
declare function local:gen-ranking-lists-for( $cmd as element(), $event-def as element() ) as element(xt:head) {
  let $init := local:lazy-initialize($event-def)
  let $sortable := local:sortable($event-def)
  let $rankings := $event-def/Rankings[@Iteration eq 'cur']
  let $final-rankings := $event-def/FinalRankings[@Iteration eq 'cur']
  let $lists := fn:head(($final-rankings, $rankings))/Lists
  let $cur-iter := max(($event-def/Rankings/@Iteration[. ne 'cur'], 0)) + 1
  let $freeze := empty($final-rankings)
  return
      <xt:head version="1.1" templateVersion="1.0" label="Data">
        <xt:component name="SubmissionDate">
          <xhtml:div class="span4">
            <xhtml:div class="control-group">
              <xhtml:label class="control-label a-gap" style="margin-right: 10px;">Submission deadline</xhtml:label>
              <xhtml:div class="controls">
                <xt:use label="SubmissionDate" param="type=date;date_region=en;date_format=ISO_8601;class=date;class=date a-control" types="input">{ $event-def/Information/Application/To/text() }</xt:use>
              </xhtml:div>
            </xhtml:div>
          </xhtml:div>
        </xt:component>
        <xt:component name="DontReOpenRejected">
          <xhtml:div class="span4">
            <xhtml:label class="control-label a-gap" style="margin: 0 20px">
              <xt:use param="type=checkbox;value=on;name=all" types="input"/> do not reopen Reject list !</xhtml:label>
          </xhtml:div>
        </xt:component>
        <xt:component name="PreDepartureDate">
          <xhtml:div class="span4">
            <xhtml:div class="control-group">
              <xhtml:label class="control-label a-gap" style="margin-right: 10px;">Pre-departure briefing date</xhtml:label>
              <xhtml:div class="controls">
                <xt:use label="PreDepartureDate" param="type=date;date_region=en;date_format=ISO_8601;class=date;class=date a-control" types="input">{ $rankings/PreDepartureDate/text() }</xt:use>
              </xhtml:div>
            </xhtml:div>
          </xhtml:div>
          {
          if (exists($rankings/Drafted) and not($rankings/Confirmed)) then
            <xhtml:div class="span4" style='float:right'>
              <xhtml:div class="control-group">
                <xhtml:label class="control-label a-gap"  style="margin-right: 10px;">Send CC to</xhtml:label>
                <xhtml:div class="controls">
                  <xt:use label="CCEmail" param="filter=optional;class=span8 a-control" types="input"></xt:use>
                </xhtml:div>
              </xhtml:div>
            </xhtml:div>
          else
            ()
          }
        </xt:component>
        {
        local:gen-component-list( $cmd, $event-def,
          if (($cur-iter > 1) and empty($rankings/Drafted)) then (: compute fresh list :)
            <MainList>
              { 
              $lists/MainList/*, local:gen-applicants($event-def)[not(./EnterpriseRef = $rankings//EnterpriseRef)] 
              }
            </MainList>
          else
            $lists/MainList,
          'main', 'span4', $sortable, $freeze
          ),
        local:gen-component-list($cmd, $event-def, $lists/ReserveList, 'reserve', 'span4', $sortable, $freeze),
        local:gen-component-list($cmd, $event-def, $rankings/Lists/RejectList, 
          if (exists($lists/CancelList)) then 'reject' else 'trash',
          'span4', not(exists($rankings/Confirmed)) and exists($rankings/Lists/RejectList), $freeze),
        if (exists($lists/CancelList)) then
          local:gen-component-list($cmd, $event-def, $lists/CancelList, 'trash', 'span4', $sortable, $freeze)
        else
          ()
        }
      </xt:head>
};

(: ======================================================================
   Generates ranking lists editor's contextual hints
   ====================================================================== 
:)
declare function local:gen-hint( $event-def as element() ) as element()* {
  let $rankings := $event-def/Rankings[@Iteration eq 'cur']
  let $final-rankings := $event-def/FinalRankings[@Iteration eq 'cur']
  let $net := misc:net-working-days( $rankings/Confirmed/@TS, current-dateTime() )
  return
    (
    <xhtml:p class="text-info" style="margin-bottom:20px">
      <xhtml:i>
        {
        concat(
          if (local:sortable($event-def)) then 
            "Drag and drop companies to refine the ranking and fill in each list. " 
          else 
            (),
          "Click on a company to see its application and/or comment it.",
          if ($rankings/Confirmed) then
            " Companies that appear in green have confirmed their own participation or intent, companies in orange haven't yet, while companies in blue have not been invited to confirm."
          else
            ()
          )
        }
      </xhtml:i>
    </xhtml:p>,
    if ($final-rankings/Confirmed) then
      <xhtml:p class="text-info" style="margin-bottom:20px"><strong>Rankings finalized by {display:gen-member-name( $rankings/Confirmed/@CreatedByRef, 'en') } on {display:gen-display-date($rankings/Confirmed/@TS, 'en')}.</strong></xhtml:p>
    else if ($rankings/Drafted and not($rankings/Confirmed)) then
      (
      <xhtml:p class="text-info" style="margin-bottom:20px"><xhtml:i>On confirmation all enterprises will be notified on their own ranking.</xhtml:i></xhtml:p>,
      <xhtml:p class="text-info" style="margin-bottom:20px"><strong>Rankings submitted by {display:gen-member-name( $rankings/Drafted/@CreatedByRef, 'en') } on {display:gen-display-date($rankings/Drafted/@TS, 'en')}.</strong></xhtml:p>
      )
    else if ($rankings/Confirmed) then
      (
      <xhtml:p class="text-info" style="margin-bottom:20px"><strong>Ranking notifications sent by {display:gen-member-name( $rankings/Confirmed/@CreatedByRef, 'en') } on {display:gen-display-date($rankings/Confirmed/@TS, 'en')}, {$net} working days elapsed since confirmation.</strong></xhtml:p>
      )
    else
      ()
    )
};

(: ======================================================================
   Generates ranking lists editor's contextual menu
   ====================================================================== 
:)
declare function local:gen-menu( $event-def as element(), $groups as xs:string* ) as element()* {
  let $draft := ('events-manager', 'admin-system')
  let $confirm := ('events-supervisor', 'admin-system')
  return
    <xhtml:div class="c-menu-scope">
      {
      let $status := local:get-workflow-status($event-def)
      return (
        local:gen-command('Submit', 1, $status, $draft, $groups, ()),
        local:gen-command('Confirm', 2, $status, $confirm, $groups, ()),
        local:gen-command('Finalize', 4, $status, ($draft, $confirm), $groups, 3)
      )
      }
    </xhtml:div>
};

(: ======================================================================
   Generates sub-editor to filter ranking lists in ranking lists editor
   ======================================================================
:)
declare function local:gen-search-editor( $event-def as element(), $lang as xs:string ) as element() {
  <xhtml:div class="row-fluid" id="search-editor" data-template="#">
    <xhtml:div class="span4">
      <xhtml:div class="control-group">
        <xhtml:label class="control-label a-gap" >Emphasize</xhtml:label>
        { custom:gen-applicants-selector( $event-def/Id, $lang, " event;multiple=yes;typeahead=yes;") }
      </xhtml:div>
    </xhtml:div>
    <xhtml:div>
    <xhtml:div class="span12">
      <xhtml:div class="span4">
        <xhtml:br/>
         <xhtml:button id="reset-selection" style="white-space: nowrap; float:right;" class="btn">Clear</xhtml:button>
          <xhtml:label class="control-label a-gap">
            <xhtml:input id="hide-unselected" style="vertical-align: -2px;white-space: nowrap" type="checkbox"/> Hide unselected
        </xhtml:label>
       </xhtml:div>
      </xhtml:div>
    </xhtml:div>
  </xhtml:div>
};

(: ======================================================================
   Returns a pseudo status number in the virtual linear ranking workflow
   ====================================================================== 
:)
declare function local:get-workflow-status( $event-def as element() ) {
  let $rankings := $event-def/Rankings[@Iteration eq 'cur']
  let $final-rankings := $event-def/FinalRankings[@Iteration eq 'cur']
  return
    if ($final-rankings/Confirmed) then
      5
    else if ($rankings/Confirmed and misc:net-working-days($rankings/Confirmed/@TS, current-dateTime()) ge 7) then
      4
    else if ($rankings/Confirmed) then
      2
    else if ($rankings/Drafted) then
      2
    else  if ($event-def/Information/Application/To < substring(string(current-date()),1,10)) then
      1
    else
      0 (: still within submission window ... only preview :)
};

declare function local:gen-reopen-component( $event-def as element(), $groups as xs:string* ) {
  let $cur-iter := max(($event-def/Rankings/@Iteration[. ne 'cur'], 0)) + 1
  let $status := local:get-workflow-status($event-def)
  return 
    <xt:component name="reopen-component">
      <xhtml:div class="span6">
        <xhtml:h2>Iteration : { $cur-iter }</xhtml:h2>
      </xhtml:div>
      {
      if ($status = (3, 4)) then (
        <xhtml:div class="span2">
          <xhtml:button id="submit-reopen" style="margin-bottom:10px" class="btn btn-primary" data-save-flags="silentErrors" data-replace-target="_none" data-target="ranking-editor" data-src="ranking?goal=reopen" data-command="save c-inhibit" data-save-confirm="Do you really want to do that, the action cannot be undone ?">Reopen lists</xhtml:button>
        </xhtml:div>,
        <xt:use types="DontReOpenRejected" label="DontReOpenRejected"/>
        )
      else
        ()
      }
    </xt:component>
};

declare function local:gen-command( $label as xs:string, $applies as xs:integer, $cur as xs:integer, $allowed as xs:string*, $groups as xs:string*, $next as xs:integer? ) {
  if ($applies eq $cur and $allowed = $groups) then
    <xhtml:button id="submit-ranking" style="margin-bottom:10px" class="btn btn-primary" data-save-flags="silentErrors" data-replace-target="_none" data-target="ranking-editor" data-src="ranking" data-command="save c-inhibit" data-save-confirm="Do you really want to do that, the action cannot be undone ?">{ $label } lists</xhtml:button>
  else if ($next eq $cur) then
    <xhtml:button style="margin-bottom:10px" class="btn btn-primary disabled">{ $label } lists</xhtml:button>
  else
    <xhtml:button style="margin-bottom:10px" class="btn disabled">{ $label } lists</xhtml:button>
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $m := request:get-method()
let $goal := request:get-parameter('goal', ())
let $tokens := tokenize($cmd/@trail, '/')
let $event-def := fn:collection($globals:events-uri)//Event[Id eq $tokens[2]]
let $groups := oppidum:get-current-user-groups()
let $submitted := oppidum:get-data()
return
  if ($m = 'POST') then
    let $errors := local:validate-submission( $submitted, $goal )
    return
      if (count($errors) > 0) then
        $errors
      else if ($goal eq 'reopen') then
        local:reopen( $cmd, $submitted, $event-def )
      else
        local:save-rankings-and-advance( $cmd, $submitted, $event-def )
  else
    if (access:check-entity-permissions('rank', 'Events', (), $event-def)) then
      let $title := custom:gen-event-title($event-def)
      let $lists := fn:head(($event-def/FinalRankings[@Iteration eq 'cur'], $event-def/Rankings[@Iteration eq 'cur']))/Lists
      return
        <Page StartLevel="1" skin="fonts extensions ranking" ResourceName="{ tokenize($cmd/@trail, '/')[4] }">
          <Window>{ $title } ranking</Window>
          <Header>
            <XT>
              { 
              local:gen-ranking-lists-for( $cmd,  $event-def ),
              local:gen-reopen-component($event-def, $groups)
              }
            </XT>
          </Header>
          <Model>
            <Navigation>
              <Mode>{ custom:get-dashboard-for-group($groups) }</Mode>
              <Key>events</Key>
              <Name>Ranking lists editor</Name>
            </Navigation>
          </Model>
          <Content>
            <Title Level="1" class="ecl-heading ecl-heading--h1">Ranking list editor for { $title }</Title>
            <xhtml:div class="row">
              <xhtml:div class="span5" style="width:100%">
                { local:gen-hint($event-def) }
              </xhtml:div>
            </xhtml:div>
            <xhtml:div class="row">
              <xhtml:div class="span5">
                { local:gen-menu($event-def, $groups) }
              </xhtml:div>
              {
              if (exists($event-def/Rankings[@Iteration eq 'cur']/Confirmed)) then
                <xhtml:div class="span3 c-menu-scope">
                  <xhtml:a class="btn" href="resources.zip" data-command="download c-inhibit" data-confirm="The ZIP archive generation is a costly operation, please use it scarcely. This functionality has been tested only on Firefox, please use that browser or you may not be able to retrieve the downloaded file. You need to allow the SME Dashboard to open popup windows to be able to download the archive. Do you confirm that you want to get an archive now ?">Download zip file</xhtml:a>
                </xhtml:div>
              else
                ()
              }
              <xhtml:div class="span12">
                { local:gen-search-editor($event-def, $lang) }
              </xhtml:div>
            </xhtml:div>
            <xhtml:hr/>
            <xhtml:div id="ranking-editor" data-template="#">
              <xhtml:div class="ecl-container">
                <xhtml:div class="row-fluid">
                  <xt:use types="PreDepartureDate"/>
                  <xt:use types="SubmissionDate"/>
                </xhtml:div>
                <xhtml:div class="row-fluid">
                  <xt:use types="reopen-component"/>
                  {
                  if (exists($lists/FinalList)) then
                    <xt:use types="FinalList" label="FinalList"/>
                  else
                    ()
                  }
                </xhtml:div>
                <xhtml:div class="row-fluid">
                  <xt:use types="MainList" label="MainList"/>
                  <xt:use types="ReserveList" label="ReserveList"/>
                  <xt:use types="RejectList" label="RejectList"/>
                  {
                  if (exists($lists/CancelList)) then
                    <xt:use types="CancelList" label="CancelList"/>
                  else
                    ()
                  }
                </xhtml:div>
              </xhtml:div>
            </xhtml:div>
          <Modals>
            <Modal Id="c-events-management" Goal="read">
              <Name>Edit details</Name>
              <Template/>
              <Commands><Save/><Close/></Commands>
            </Modal>
          </Modals>
          </Content>
        </Page>
    else
      oppidum:throw-error('FORBIDDEN', ())
