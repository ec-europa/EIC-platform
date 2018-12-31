xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   Events controller to build different kinds of lists of events :
   - a list of all the events for application by a single company
   - a list of all the events for exporting all applications
   - a list of all the events for editing meta-data or sorting applications

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../modules/enterprises/enterprise.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../../xcm/lib/database.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:delay := 7; (: see also Event_Confirmation_Delay in variables.xml :)

declare function local:gen-link-towards-form( $cmd as element(), $event as xs:integer, $can-submit as xs:boolean ) as attribute()? {
  if ($can-submit) then
    attribute { 'Link' } { 
      concat($cmd/@base-url, $cmd/@trail, '/form/', $event) 
    }
  else
    ()
};

(: ======================================================================
   TODO: to open to $crawler (event managers) requires to test Event category
   against event manager programmes
   ====================================================================== 
:)
declare function local:gen-application-link( $cmd as element(), $event as element(), $enterprise as element(), $crawler as xs:boolean ) {
  let $can-submit := enterprise:can-apply-to-event($enterprise, $event)
  let $date := substring(string(fn:current-date()), 1, 10)
  let $applied := $enterprise/Events/Event[Id eq $event/Id]
  let $app-time-range := concat(display:gen-display-date($event//Application/From, 'en'), ' - ', display:gen-display-date($event//Application/To, 'en'))
  return
    <Application>
      {
      (: 1. Not yet - no Link no @Satellite :)
      if ($date < $event//Application/From) then 
        concat('Apply (', $app-time-range, ')')

      (: 2. Too late - Link with @Satellite and @On or @Since :)
      else if ($event//Application/To < $date) then 
        (
        if ($applied) then
          let $status := $applied/StatusHistory/CurrentStatusRef
          let $date := $applied/StatusHistory/Status[ValueRef eq $applied/StatusHistory/CurrentStatusRef]/Date
          return (
            local:gen-link-towards-form($cmd, $event/Id, $can-submit),
            attribute { 'Satellite' } {
              if ($status eq '1') then
                'draft saved'
              else if ($status eq '2') then
                if ($applied/Data/Application/@ImportDate) then
                  'imported'
                else
                  'submitted'
              else if ($status eq '3') then
                'awaiting confirmation'
              else if ($status eq '4') then
                'finalized'
              else
                (:FIXME: decode Status using real event worklow id (not always OTF):)
                lower-case(display:gen-name-for('OTF', $applied/StatusHistory/CurrentStatusRef, 'en'))
              },
              if ($status eq '1') then
                attribute { 'On' } { display:gen-display-date($applied/Data/Application/@LastModification, 'en') }
              else if ($status eq '2') then
                if ($applied/Data/Application/@ImportDate) then
                  attribute { 'On' } { display:gen-display-date($applied/Data/Application/@ImportDate, 'en') }
                else
                  attribute { 'On' } { display:gen-display-date($date, 'en') }
              else
                attribute { 'Since' } { display:gen-display-date($date, 'en') }
          )
        else if ($can-submit) then
          attribute { 'Satellite' } { 'not submitted' }
        else
          (),
        'Closed'
        )

      (: 3. Can apply - Link w/o @Satellite :)
      else
        (
        (: Workaround: suppress 'Berlinevent' test when the subbmission form is ready :)
        if ((not($crawler) or $applied)(: and (not($event[Information/Name/text() eq 'Berlin event'])):)) then
          local:gen-link-towards-form($cmd, $event/Id, $can-submit)
        else
          (),
        if (not($applied)) then
          if ($date > $event//Application/From) then
            concat('Apply by ', display:gen-display-date($event//Application/To, 'en'))
          else
            concat('Apply now (', $app-time-range, ')')
        else
          let $status := $applied/StatusHistory/CurrentStatusRef
          return
            if ($status eq '1') then
              'Draft saved'
            else if ($status eq '2') then
              'Submitted'
            else
              (:FIXME: decode Status using real event worklow id (not always OTF):)
              display:gen-name-for('OTF', $applied/StatusHistory/CurrentStatusRef, 'en')
        )
    }
    </Application>
  };

(: ======================================================================
   A non-staff user can view only his/her own registrations/feedbacks
   ====================================================================== 
:)
declare function local:get-enterprise( $cmd as element(), $staff as xs:boolean, $crawler as xs:boolean, $name as xs:string, $uid as xs:string ) as element()? {
  if (matches($name, '\d+')) then (: Company Dashboard viewing :)
    let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $name]
    let $access := access:get-entity-permissions('view', 'Events', $enterprise) (: FIXME: 'Dashboard' ? :)
    return
      if (local-name($access) eq 'allow') then
        $enterprise
      else
        $access
  else if (($staff or $crawler) and $name = ('export', 'management')) then  (: Multi-Dashboard viewing by EASME staff member :)
    (: staff always belongs to EASME (Id 1) per construction - 
       this way it works even if Status has been changed for testing purposes :)
    fn:collection($globals:enterprises-uri)//Enterprise[Id eq '1']
  else
    let $enterprise := enterprise:get-my-enterprises()
    let $valid := fn:filter($enterprise, function ($x) { enterprise:is-valid($x) } )
    let $projects := fn:filter($valid, function ($x) { enterprise:has-projects($x) } )
    return
      if (empty($enterprise)) then
        oppidum:throw-error('NOT-MEMBER-ERROR', ())
        (: FIXME: logout and show same message as with <Check Email="notfound"/> in login procedure ? :)
      else if (exists($valid)) then
        if (exists($projects)) then
          if (count($projects) > 1) then
            <Redirected>{ oppidum:redirect(concat($cmd/@base-url, 'switch')) }</Redirected>
          else
            <Redirected>{ oppidum:redirect(concat($cmd/@base-url, $enterprise/Id)) }</Redirected>
        else
          oppidum:throw-error('NO-RUNNING-PROJECTS', string-join($enterprise/Information/ShortName, ', '))
      else
        oppidum:throw-error('NO-VALID-ENTERPRISES', string-join($enterprise/Information/ShortName, ', '))
};

declare function local:make-feedbacks-link-for-export( $cmd as element(), $event as element(), $dg as xs:boolean ) as element()? {
  let $event-no := $event/Id
  (: FIXME: replace trick with EventKey in Feedback, but this requires to migrate legacy submissions :)
  (: trick because feedback entity uses mirror of event entity sharding as per database.xml :)
  let $mirror := database:gen-collection-for-key ('', 'event', $event-no) 
  let $resource-uri := concat($globals:feedbacks-uri, '/', $mirror, '/', $event-no, '.xml')
  let $total := count(fn:doc($resource-uri)//Feedback)
  let $href := concat($cmd/@base-url, 'feedbacks/events/', $event-no)
  return
    if ($total > 0) then
      <Index Submitted="{ $total }">
        { if (not($dg)) then attribute { 'Link' } { $href } else () }
      </Index>
    else
      <Index/>
};

declare function local:gen-excel-link( 
  $events as element()*, 
  $id as xs:string, 
  $status-str as xs:string, 
  $doc-name as xs:string, 
  $category as xs:string, 
  $dg as xs:boolean, 
  $href as xs:string ) 
{
  let $status-no := number($status-str)
  return
    let $hmd := count(
      $events[Id = $id][StatusHistory/CurrentStatusRef eq $status-str and exists(Data/*[local-name(.) eq $doc-name])]
      )
    let $hms := count(
      $events[Id = $id][number(StatusHistory/CurrentStatusRef) gt $status-no and exists(Data/*[local-name(.) eq $doc-name])]
      )
    return
      if ($hmd + $hms > 0) then 
        <Excel Category="{ $category }" Draft="{ $hmd }" Submitted="{ $hms }">
          { if (not($dg)) then attribute { 'Link' } { $href } else () }
        </Excel>
      else
        <Excel Category="{ $category }"/>
};
    
(: ======================================================================
   Returns a list of events model for exportation of all applications
   ====================================================================== 
:)
declare function local:make-list-for-export( $cmd as element(), $events-def as element()+, $enterprise as element(), $programme as element(), $dg as xs:boolean ) as element()+ {
  let $progId := string($programme/@WorkflowId)
  let $wfl-defs := fn:collection($globals:global-info-uri)//Description[@Lang = $cmd/@lang]//Selector[@Name eq $progId]
 (: cache for loop invariant :)
  let $evt-beneficiaries := globals:collection('enterprises-uri')//Enterprise[empty(Settings/Teams)]//Event
  let $evt-investors := globals:collection('enterprises-uri')//Enterprise[Settings/Teams eq 'Investor']//Event
  return
    <EventExportList>
      {
      $programme,
      <Statuses>
        {
        for $def in $wfl-defs/Option[not(@Type eq 'final')][Export]
        order by number($def/Value) ascending 
        return 
          <Status Id="{ $def/Value }">{ $def/Name/text() }</Status>
        }
        <Status Id="_last">Investors Feedback</Status>
      </Statuses>,
      for $event in $events-def 
      let $id := $event/Id
      order by $event//Date/From/text() ascending
      return
        <Event>
          {
          $event/PublicationStateRef,
          $event//Name,
          $event//Topic,
          $event//WebSite,
          let $docs := fn:doc(oppidum:path-to-config('application.xml'))//Workflow[@Id eq $progId]
          return
            for $def in $wfl-defs/Option[not(@Type eq 'final')][Export]
            let $status := $def/Value
            let $doc-name := $def/Export
            let $ress := $docs//Document[Action[@Type eq 'update' and @AtStatus eq $status]]/Resource
            order by number($status) ascending
            return
              <Excels For="{ $def/Value }">
              {
              let $href := concat($cmd/@base-url, 'form/', $id, '/', $ress, '.xlsx')
              return
                local:gen-excel-link($evt-beneficiaries, $id, $status, $doc-name, 'beneficiary', $dg, $href),
              if ($event/Processing[@Role='investor']) then
                let $href := concat($cmd/@base-url, 'form/', $id, '/', $ress, '.xlsx?export=2')
                return
                  local:gen-excel-link($evt-investors, $id, $status, $doc-name, 'investor', $dg, $href)
              else
                ()
              }
              </Excels>,
          local:make-feedbacks-link-for-export($cmd, $event, $dg)
          }
        </Event>
      }
    </EventExportList>
};

(: ======================================================================
   Returns a list of events model for management of selection process
   ====================================================================== 
:)
declare function local:make-list-for-management( $cmd as element(), $events-def as element()+, $enterprise as element(), $programme as element(), $staff as xs:boolean, $crawler as xs:boolean ) as element()+ {
  let $progId := string($programme/@WorkflowId)
  let $wfl-defs := fn:collection($globals:global-info-uri)//Description[@Lang = $cmd/@lang]//Selector[@Name eq $progId]
  let $today := substring(string(current-date()),1,10)
  return
    <EventManagementList>
      {
      $programme,
      for $event in $events-def 
      let $all-event-app := globals:collection('enterprises-uri')//Enterprise//Event[Id = $event/Id]
      let $rankings := $event/Rankings[@Iteration eq 'cur']
      let $final-rankings := $event/FinalRankings[@Iteration eq 'cur']
      order by $event//Date/From/text() ascending
      return
        <Event>
          {
          $event/PublicationStateRef,
          if ($staff) then <Editable Link="{ concat($cmd/@base-url, 'form/', $event/Id, '/edit') }"/> else (),
          if ($event/PublicationStateRef eq '1' and string($event//Name) eq '') then
            <Name>
              { concat($event/Template, ' (', $event/Programme/@WorkflowId, ')') }
            </Name>
          else
            $event//Name,
          if ($event/PublicationStateRef eq '1' and string($event//Topic) eq '') then
            <Topic>
              { concat($event/Template, ' (', $event/Programme/@WorkflowId, ')') }
            </Topic>
          else
            $event//Topic,
          let
            $ready := count($all-event-app/StatusHistory/CurrentStatusRef[. eq '2']),
            $finalization := count($all-event-app/StatusHistory/CurrentStatusRef[. eq '3']),
            $confirm-ready := count($all-event-app/StatusHistory/CurrentStatusRef[. eq '4']),
            $href := concat( $cmd/@base-url, 'form/', $event/Id, '/ranking'),
            $undefined := not($event//Application/(From|To) and $event//Date/(From|To)),
            $closed := ($event//Application/To < $today),
            $notyet := ($today < $event//Application/From),
            $netwd := if ($rankings/Confirmed) then misc:net-working-days( $rankings/Confirmed/@TS, current-dateTime() ) else 0,
            $ranking := $closed and (($ready + $finalization + $confirm-ready) gt 0)
          return
            if ($undefined) then 
              <Undefined/>
            else (: dates properly defined :)
              element
              {
                if ($event//Application/To < $today) then
                  if ($final-rankings/Confirmed) then
                    'Finalized'
                  else if ($rankings/Confirmed) then
                    if ($netwd < $local:delay) then
                      'FinalizationStandBy'
                    else
                      'Finalization'
                  else if ($ready gt 0) then
                    if ($rankings/Drafted) then
                      'Confirmation'
                    else
                      'Evaluation'
                  else if (exists($event//Rankings[@Iteration])) then
                    'ReOpened'
                  else
                    'Nothing'
                else if ($notyet) then
                  'NotYet'
                else if (exists($event//Rankings[@Iteration])) then
                  'ReOpened'
                else
                  'NotClosed'
              }
              {
                attribute Submitted { 
                  if ($final-rankings/Confirmed) then
                    $confirm-ready
                  else if ($rankings/Confirmed) then
                    if ($netwd < $local:delay) then
                      $finalization
                    else
                      $finalization + $confirm-ready
                  else if (exists($rankings)) then
                    $ready + $finalization + $confirm-ready
                  else
                    $ready
                },
                if ($staff) then attribute Supervisor { $staff } else attribute Manager { $crawler },
                attribute LastDay { display:gen-display-date($event//Application/To, 'en') },
                if ($ranking) then
                  (
                  (: check workflow is compatible with ranking :)
                  if ($wfl-defs/Option/Value = 3) then 
                    attribute Link { $href }
                  else 
                    (),
                  attribute Status 
                  {
                  (: FIXME: use latest itration :)
                  if ($final-rankings/Confirmed) then
                    'events-manager events-supervisor'
                  else if ($rankings/Drafted) then (: next step => events supervisor :)
                    'events-supervisor'
                  else (: nothing has been done yet => :)
                    'events-manager'
                  },
                  if ($netwd < $local:delay) then attribute Elapsed { $netwd } else ()
                  )
                else if ($notyet) then
                  attribute FirstDay { display:gen-display-date($event//Application/From, 'en') }
                else if (exists($event//Rankings[@Iteration])) then
                  attribute Link { $href }
                else
                  ()
              }
          }
        </Event>
      }
    </EventManagementList>
};

(: ======================================================================
   Returns a list of events model for application by a single company
   ====================================================================== 
:)
declare function local:make-list-for-application( $cmd as element(), $events-def as element()+, $enterprise as element(), $programme as element(), $crawler as xs:boolean, $can-apply as xs:boolean ) as element()+ {
  <EventApplicationList CanApply="{ $can-apply }">
    {
    $programme,
    for $event in $events-def
    let $pub := if ($event/PublicationStateRef) then $event/PublicationStateRef/text() else '2'
    where $pub = '2' or ($enterprise/Settings/Events eq 'all')
    order by $event//Date/From ascending
    return 
      <Event>
        <PublicationStateRef>{ $pub }</PublicationStateRef>
        {
        $event/Id,
        $event//Name,
        $event//WebSite,
        $event//Topic,
        $event//Resources,
        <Location>{ if ($event//Location/*) then string-join($event//Location/*, ', ') else () }</Location>,
        <Date>{ if ($event//Date/*) then display:gen-display-date-range($event//Date/*, 'en') else () }</Date>,
        if ($event//Application/*) then 
          local:gen-application-link($cmd, $event, $enterprise, $crawler)
        else
          <Application/>
      }
      </Event>
    }
  </EventApplicationList>
};

(: ======================================================================
   Helper function to refine UI feedback in case the organisation cannot 
   apply to any event category
   ====================================================================== 
:)
declare function local:can-apply-to-some-event( $enterprise as element() ) as xs:boolean {
  let $org-type := enterprise:organisationType($enterprise/Id)
  return
    $org-type = ('Beneficiary', 'Investor', 'Investor / Corporate')
};

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $id := string($cmd/resource/@name)
let $profile := user:get-user-profile()
let $person := $profile/parent::Person
let $staff := oppidum:get-current-user-groups() = ('admin-system', 'project-officer', 'developer')
let $dg := not($staff) and oppidum:get-current-user-groups() = ('dg')
let $crawler := not($staff) and oppidum:get-current-user-groups() = ('events-manager')
let $enterprise := local:get-enterprise( $cmd, $staff or $dg, $crawler, $id, $person/Id)
let $export := ($staff or $crawler or $dg) and ($id eq 'export')
let $management := ($staff or $crawler or $dg) and ($id eq 'management')
let $title := if ($export) then 'Events Manager export view' else if ($management) then 'Events Manager management view' else concat(custom:gen-enterprise-title($enterprise), ' events')
return
  if (local-name($enterprise) ne 'error') then
    let $warning := if ($dg and $export) then 
                      oppidum:throw-message('INFO', 'You can get an overview of the submitted applications and feedbacks, however your role does not allow you to export submitted data')
                    else
                      ()
    let $can-apply := local:can-apply-to-some-event($enterprise)
    return
      <Page StartLevel="1" skin="fonts extensions accordion" ResourceName="{ $id }">
        <Window>{ $title }</Window>
        <Model>
          <Navigation>
            <Key>events</Key>
            <Name>{ $title }</Name>
            {
            if ($export or $management) then
              <Mode>{ if ($staff) then 'multi' else 'unaffiliated' }</Mode>
            else
              (
              <Mode>{ if ($crawler) then 'evmgr-single' else 'single' }</Mode>,
              <Resource>{ $id }</Resource>
              )
            }
          </Navigation>
        </Model>
        <Content>
          <Title Level="2" class="ecl-heading ecl-heading--h2">Events List</Title>
            {
            let $hint := if ($export) then 
                           'Retrieve all registrations/feedbacks data by step.' 
                         else if ($can-apply) then 
                           'Get more details about your application statuses by clicking on these.'
                         else
                           ()
            return
              if (not($export) and not($management)) then
                <p class="text-info" style="margin-bottom:20px"><i>Click on an event name or topic for more details about it. {$hint}</i></p>
              else
                ()
            }
          <div id="events-management">
          {
          for $ev in fn:collection($globals:events-uri)/Event
          let $prog := $ev/Programme
          group by $prog
          return
            if (not($crawler) or $ev[1]/Programme/@WorkflowId = $profile//Role[FunctionRef eq '5']/ProgramId) then
              if ($export) then
                local:make-list-for-export($cmd, $ev, $enterprise, $prog, $dg) 
              else if ($management) then
                local:make-list-for-management($cmd, $ev, $enterprise, $prog, $staff, $crawler)
              else
                local:make-list-for-application($cmd, $ev, $enterprise, $prog, $crawler, $can-apply)
            else
              ()
          }
          </div>
          <Modals>
            <Modal Id="c-events-management" Goal="read">
              <Name>Event configuration</Name>
              <Template/>
              <Commands>
                <Save data-src="duplicate" data-save-confirm="Are you sure ?">
                  <Label>Duplicate</Label>
                </Save>
                <Save/>
                <Close/>
              </Commands>
            </Modal>
          </Modals>
        </Content>
      </Page>
  else
    $enterprise
