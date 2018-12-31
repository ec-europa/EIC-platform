xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Support method to compute alerts and cache them into a collection

   Pre-conditions : $globals:checks-uri and $globals:reminders-uri
   collections available and "rwu"-able for user executing this script
   (which can be guest if run from scheduler job)

   May 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace check = "http://oppidoc.com/ns/cctracker/alert/check";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../../oppidum/lib/compat.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../../lib/media.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "../workflow/alert.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";
import module namespace email = "http://oppidoc.com/ns/cctracker/mail" at "../../lib/mail.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare variable $check:today := current-date();
(:declare variable $check:today := xs:date("2015-12-01");:)

(: ======================================================================
   Formats and returns cases and upate cache collection
   ======================================================================
:)
declare function check:cache-update( $check as element(), $cases as element()* ) as element() {
  let $res :=
    <Check No="{$check/@No}" Title="{$check/Title}" Timestamp="{current-dateTime()}" Total="{count($cases)}">
      {(
      $check/@Threshold,
      attribute When { if (exists($check/When/@Project)) then 'Project' else if (exists($check/When/@Case)) then 'Case' else 'Activity' },
      $cases
      )}
    </Check>
  return
    if (xdb:collection-available($globals:checks-uri)) then
      let $cache-file := concat($check/@No, '.xml')
      let $stored-path := xdb:store($globals:checks-uri, $cache-file, $res)
      return
        if(not($stored-path eq ())) then (
          (: in case not owned by admin:users changes permissions (e.g.. when created first time from scheduler as guest)
             alternative would be to execute scheduled task as admin (?)
          :)
          if ((xdb:get-group($globals:checks-uri, $cache-file) ne 'users')
              or (xdb:get-owner($globals:checks-uri, $cache-file) ne 'admin')) then
            (: xdb:set-resource-permissions($globals:checks-uri, $cache-file, 'admin', 'users', util:base-to-integer(0771, 8)) :)
            compat:set-owner-group-permissions(concat($globals:checks-uri, '/', $cache-file), 'admin', 'users', "rwxrwxr-x")
          else
            (),
          $res
          )
        else
          $res
    else
      $res
};

(: ======================================================================
   Returns the list of user references holding the semantic role suffix
   for the given Case or Activity
   See also: lib/access.xqm access:assert-semantic-role
   ======================================================================
:)
declare function local:get-semantic-role( $suffix as xs:string, $project as element(), $case as element(), $activity as element()? ) as xs:string* {
  let $group-ref := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role eq $suffix]/Id/text()
  return
    if ($suffix eq 'region-manager') then
      let $region-entity := $case/ManagingEntity/RegionalEntityRef/text()
      return
        fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[(FunctionRef eq $group-ref) and (RegionalEntityRef eq $region-entity)]]/Id/text()
    else if ($suffix eq 'kam') then
      $case/Management/AccountManagerRef/text()
    else if ($suffix eq 'coach') then
      $activity/Assignment/ResponsibleCoachRef/text()
    else if ($suffix eq 'service-head') then
      let $service := $activity/Assignment/ServiceRef/text()
      return
        fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[(FunctionRef eq $group-ref) and (ServiceRef eq $service)]]/Id/text()
    else
      ()
};

declare function local:gen-responsibles ( $check as element(), $project as element(), $case as element()?, $activity as element()? ) as xs:string* {
  for $rule in $check/Responsible/Meet/text()
  let $prefix := substring-before($rule, ':')
  return
      if ($prefix eq 'r') then
        local:get-semantic-role(substring-after($rule, ':'), $project, $case, $activity)
      else
        ()
};

declare function local:gen-start( $base as element(), $start as element(), $status as xs:string ) as xs:date? {
  if ($start eq 'enter') then
    xs:date(substring($base/StatusHistory/Status[ValueRef eq $status]/Date, 1, 10))
  else
    let $res := util:eval($start/text())
    return
      if ($res castable as xs:dateTime) then
        xs:date(substring($res, 1, 10))
      else if ($res castable as xs:date) then
        xs:date($res)
      else
        ()
};

declare function local:gen-stop( $base as element(), $stop as element() ) as xs:date? {
  if ($stop eq 'leave') then
    $check:today
  else
    let $res := util:eval($stop/text())
    return
      if (exists($res) and ((count($res) > 1) or ($res ne '')) ) then (: action has been done :)
        ()
      else
        $check:today
};

(: ======================================================================
   If the check still applies to the Case or Activiy item returns
   number of days ellapsed since it beginning otherwise returns the empty sequence
   FIXME: return xs:integer ?
   ======================================================================
:)
declare function local:check-duration( $item as element(), $check as element(), $status as xs:string ) as xs:string? {
  let $stop := local:gen-stop($item, $check/Stop)
  return
    if (exists($stop)) then
      let $start := local:gen-start($item, $check/Start, $status)
      return
        if (exists($start)) then
          string(days-from-duration($stop - $start))
        else
          () (: action not started yet, not yet on todo list :)
    else (: action already done, no more on todo list :)
      ()
};

(: ======================================================================
   Returns a pre-computed Case model to be stored in global To Do list for given check
   ======================================================================
:)
declare function local:gen-sample( $check as element(), $project as element(), $case as element()?, $activity as element()?, $dur as xs:string? ) as element()? {
  if ($dur) then
      <Project Id="{$project/Id}">
        { if ($case) then attribute CaseNo { string($case/No) } else () }
        { if ($activity) then attribute ActivityNo { string($activity/No) } else () }
        <Run>{ $dur }</Run>
        { $project/Id }
        { $project/Information/Acronym }
        <Call>
          <MasterCall>{collection($globals:global-info-uri)//Selector/Group[Selector/Option/(Id | Code)[. = $project/Information/Call/(SMEiCallRef | FTICallRef | FETCallRef) ]]/Name/text()}</MasterCall>
          <CallRef>{ string(misc:unreference($project/Information/Call/(SMEiCallRef | FTICallRef | FETCallRef ))/@_Display) }</CallRef>
          <FundingRef>{ string(misc:unreference($project/Information/Call/(SMEiFundingRef | FETActionRef))/@_Display) }</FundingRef>
        </Call>
        {
          for $e in $project/Information/Beneficiaries/(Coordinator | Partner)
          where not($case) or $case[PIC eq $e/PIC]
          return
            <Case>
              <SME>{ $e/Name/text() }</SME>
              { $e/Address/Country }
              {
              if ($case) then 
                <KAM>{ display:gen-name-person($case/Management/AccountManagerRef/text(), 'en') }</KAM>
              else
                (),
              if ($activity) then
                <Coach>{ display:gen-name-person($activity/Assignment/ResponsibleCoachRef/text(), 'en') }</Coach>
              else
                (),
              if ($case/ManagingEntity/RegionalEntityRef) then
                <KC>{ display:gen-names-region-manager($case/ManagingEntity/RegionalEntityRef, 'en') }</KC>
              else 
                (),
              for $r in local:gen-responsibles($check, $project, $case, $activity)
              return <ReRef>{ $r }</ReRef>
              }
            </Case>
        }
      </Project>
  else
    ()
};

(: ======================================================================
   TODO: compute stop - start (?)
   FIXME: currently <Eval> does not take <When> into account (same as "*")
   ======================================================================
:)
declare function local:gen-eval( $check as element(), $status as xs:string? ) as element()* {
  for $item in util:eval($check/Eval/text())
  return
    if (local-name($item) = 'Project') then
      local:gen-sample($check, $item, (), (), "-")
    else
      local:gen-sample($check, $item/../.., $item, (), "-")
};

(: ======================================================================
   Applies one check and returns the list of cases falling under the check
   TODO: $lang
   ======================================================================
:)
declare function check:check ( $check as element() ) as element()* {
  let $project-status := if ($check/When/@Project) then $check/When/text() else ()
  let $case-status := if ($check/When/@Case) then $check/When/text() else ()
  let $activity-status := if ($check/When/@Activity) then $check/When/text() else ()
  return
    if ($check/Eval) then (: currently synonym with <When Case="*"> :)
      local:gen-eval($check, $case-status)
    else
      for $p in fn:collection($globals:projects-uri)//Project[empty($project-status) or (StatusHistory/CurrentStatusRef eq $project-status)]
      return
        if ($check/When/@Project) then
          local:gen-sample($check, $p, (), (), local:check-duration($p, $check, $project-status))
        else if ($check/When/@Case) then
          for $c in $p//Case[StatusHistory/CurrentStatusRef eq $case-status]
          return
            local:gen-sample($check, $p, $c, (), local:check-duration($c, $check, $case-status))
        else if ($check/When/@Activity) then
          for $a in $p//Case//Activity[StatusHistory/CurrentStatusRef eq $activity-status]
          return
            local:gen-sample($check, $p, $a/../.., $a, local:check-duration($a, $check, $activity-status))
        else
          ()
};

(: ======================================================================
   Returns list of Reminder for given Case and Activity checked at duration with given check
   ======================================================================
:)
declare function local:gen-reminders-for-check( $check as element(), $project as element(), $case as element()?, $activity as element()?, $dur as xs:string? ) as element()* {
  let $curtime := number($dur)
  return
    for $e in $check/(Email|Status)
    let $max := if ($e/@Until) then number($e/@Until) else $curtime
    return
      if (($e/@Elapsed eq $dur)
          or (($e/@Mode eq 'robust') and ($curtime gt number($e/@Elapsed)) and ($curtime le $max))) then
        element
        {
          if (local-name($e) eq 'Email') then 'Reminder' else 'AutoAdvance'
        }
        {
          attribute curtime { $curtime },
          attribute dur { $dur },
          attribute { 'PID' } { $project/Id },
          if ($e/@Mode eq 'robust') then attribute { 'Time' } { $dur } else (),
          $e/@Elapsed,
          if ($activity) then
            attribute { 'CaseNo' } { $case/No }
          else
            (),
          if ($activity) then
            attribute { 'ActivityNo' } { $activity/No }
          else
            (),
          if (local-name($e) eq 'Status') then
            ($e/@To, $e/To)
          else
            (),
          $project/Information/Acronym,
          $e/*[not(local-name(.) = ('Description', 'To'))]
        }
      else
        ()
};

(: ======================================================================
   Applies one check for e-mail reminders
   Return a list of Reminder and AutoAdvance elements to execute
   ======================================================================
:)
declare function check:reminders-for-check ( $check as element() ) as element()* {
  let $project-status := if ($check/When/@Project) then $check/Project/text() else ()
  let $case-status := if ($check/When/@Case) then $check/When/text() else ()
  let $activity-status := if ($check/When/@Activity) then $check/When/text() else ()
  return
    if ((empty($check/Email) and empty($check/Status)) or $check/Eval) then (: Eval synonym with <When Case="*"> :)
      ()
    else
      for $p in fn:collection($globals:projects-uri)//Project[empty($project-status) or (StatusHistory/CurrentStatusRef eq $project-status)]
      return
        if ($check/When/@Project) then
          local:gen-reminders-for-check($check, $p, (), (), local:check-duration($p, $check, $project-status))
        else if ($check/When/@Case) then
          for $c in $p//Case[StatusHistory/CurrentStatusRef eq $activity-status]
          return 
            local:gen-reminders-for-check($check, $p, $c, (), local:check-duration($c, $check, $case-status))
        else if ($check/When/@Activity) then
          for $a in $p//Case//Activity[StatusHistory/CurrentStatusRef eq $activity-status]
          return
            local:gen-reminders-for-check($check, $p, $a/../.., $a, local:check-duration($a, $check, $activity-status))
        else
          ()
};

(: ======================================================================
   Returns key property value from settings.xml with fallback
   FIXME: to be moved to util.xqm ?
   ======================================================================
:)
declare function local:get-setting( $key as xs:string, $fallback as xs:string? ) as xs:string? {
  let $res := fn:doc($globals:settings-uri)/Settings/Module[Name eq 'reminders']/Property[Key eq $key]
  return
    if ($res) then
      $res/Value/text()
    else
      $fallback
};

(: ======================================================================
   Implements Cancel in to restrain sending Email notification 
   depending on Case and/or Activity content
   ====================================================================== 
:)
declare function local:cancel-reminder( $r as element(), $project as element(), $case as element()?, $activity as element()? ) as xs:boolean {
  if ($r/Cancel) then
    util:eval($r/Cancel/text())
  else
    false()
};

(: ======================================================================
   Implements Reminder model to send and archive an alert to some Recipients
   Default sender (reply-to) is defined in settings.xml
   Returns a status string
   FIXME: currently reminders must be Alert only elements in mail.xml (!)
   ======================================================================
:)
declare function local:apply-reminder( $r as element(), $enabled as xs:string ) {
  let $project := fn:collection($globals:projects-uri)/Project[Id eq $r/@PID]
  let $case := if ($r/@CaseNo) then $project/Cases/Case[No eq $r/@CaseNo] else ()
  let $activity := if ($r/@ActivityNo) then $case/Activities/Activity[No eq $r/@ActivityNo] else ()
  let $host := if ($activity) then $activity else if ($case) then $case else $project
  return
    (: First filters out notification if already sent and limited to 1 exemplary :)
    if (($r/Recipients/@Max eq '1') and ($r/Recipients/@Key) and ($host/Alerts/Alert[Key eq tokenize($r/Recipients/@Key, ' ')[1]])) then
      let $prefix := if ($enabled eq 'on') then '' else 'off+'
      return
        (: makes the distinction between discarded messages because repeateadly testing on a robust interval
           and messages already sent when testing the first day most likely because workflow loopback :)
        if ($r/@Time and ($r/@Time ne $r/@Elapsed)) then
          concat($prefix, 'discard')
        else (: workflow must have done a loopback :)
          concat($prefix, 'double')
    else if (local:cancel-reminder($r, $project, $case, $activity)) then
      'cancelled'
    else if ($enabled eq 'on') then
      (: TODO: more defensive in case Case or Activity not found ? :)
      let $pre := email:render-alert($r/Template, 'en', $project, $case, $activity, ())
      let $mail := <Alert Mode="auto">{ $pre/@*, $pre/* }</Alert>
      let $from := if ($mail/From) then
                     $mail/From/text()
                   else
                     local:get-setting('default-email-reply-to', ())
      let $report := alert:apply-recipients($r/Recipients, 'reminders', $project, $case, $activity, $mail, $from,
                        $host/StatusHistory/CurrentStatusRef, ())
      return
        if ($report/@Total ne '0') then
          if (media:is-plugged('reminders')) then
            if ($report/error) then (: sent but not archived because of error :)
              'sent'
            else  (: sent and archived :)
              'done'
          else
            if ($report/error) then (: not sent and not archived because of error :)
              'off'
            else (: not sent and archived :)
              'unplugged'
        else (: not sent because of error and not archived :)
          'fail'
    else
      $enabled
};

(: ======================================================================
   Returns the target status for the transition by implementing :
      <Status @To> 
   or 
      <Status>
        <To>
          <When Test="xpath condition">X</When>
          <Otherwise>Y</Otherwise>
        </To>
      </Status>
   ====================================================================== 
:)
declare function local:get-transition-to( $r as element(), $project as element(), $case as element()?, $activity as element()? ) as xs:string? {
  if ($r/To) then
    let $matches := (: FIXME: would be more efficient to stop at first match :)
      for $when in $r/To/When
      where util:eval(string($when/@Test))
      return $when
    return
      if (exists($matches)) then $matches[1] else $r/To/Otherwise
  else
    $r/@To
};

(: ======================================================================
   Implements AutoAdvance which bypasses the workflow transition system 
   and jumps directly to a new-status
   Returns 'updated' on success or 'failed' otherwise if enabled by settings.xml
   ======================================================================
:)
declare function local:apply-autoadvance( $r as element(), $enabled as xs:string ) {
  let $project := fn:collection($globals:projects-uri)/Project[Id eq $r/@PID]
  let $case := $project/Cases/Case[No = $r/@CaseNo]
  let $activity := $case/Activities/Activity[No = $r/@ActivityNo]
  return
    if ($enabled eq 'on') then
      let $to := local:get-transition-to($r, $project, $case, $activity)
      return
        if ($to and empty(workflow:apply-transition-to($to, $project, $case, $activity))) then
          'updated'
        else
          'failed'
    else
      concat($enabled, ' (', local:get-transition-to($r, $project, $case, $activity), ')')
};

(: ======================================================================
   Applies a sequence of Reminder or AutoAdvance reminders 
   AutoAdvance may have a Template to send an e-mail (not used, DEPRECATED)
   in addition to changing the status

   Returns the sequence of reminders annotated by outcome for archiving

   Those side effects are controlled by an 'enabled' property of
   the 'reminders' module in settings.xml which must be set to 'on'

   Do not archive a Reminder when it returns the discard status and the alerts
   module is enabled, archives it otherwise (debug purpose)

   Note: e-mail side effect is unique and identified with a Key to prevent
   sending twice an e-mail already archived into the Case / Activity
   ======================================================================
:)
declare function check:apply-reminders( $reminders as element()*, $run as xs:boolean ) as element()* {
  let $enabled := if ($run) then local:get-setting('enabled', 'off') else 'off'
  return
    for $r in $reminders
    return
      if ((local-name($r) eq 'Reminder')) then
        let $status := local:apply-reminder($r, $enabled)
        return
          if ($enabled eq 'off' or $status ne 'discard') then
            <Reminder Status="{$status}">
              { 
              $r/@*, $r/*[local-name(.) ne 'Cancel'],
              if ($enabled eq 'off') then (: debug purpose :)
                let $project := fn:collection($globals:projects-uri)/Project[Id eq $r/@PID]
                let $case := if ($r/@CaseNo) then $project/Cases/Case[No eq $r/@CaseNo] else ()
                let $activity := if ($r/@ActivityNo) then $case/Activities/Activity[No eq $r/@ActivityNo] else ()
                let $pre := email:render-alert($r/Template, 'en', $project, $case, $activity, ())
                let $to :=  if ($pre/To) then
                              $pre/To/text()
                            else
                              workflow:gen-recipient-refs($r/Recipients, (), $project, $case, $activity)
                return
                  for $ref in $to
                  return
                    <To>
                      {
                      if (matches($ref, '^\d*$')) then
                        display:gen-person-email($ref, 'en') 
                      else
                        $ref
                      }
                    </To>
              else
                ()
              }
            </Reminder>
          else
            ()
      else if (local-name($r) eq 'AutoAdvance') then (: status change side effect :)
        <AutoAdvance WorkflowStatus="{local:apply-autoadvance($r, $enabled)}">
        {
        if ($r/Template) then (: DEPRECATED: e-mail side effect :)
          attribute { 'Status' } { local:apply-reminder($r, $enabled) }
        else
          (),
        $r/@*,
        $r/*[local-name(.) ne 'To']
        }
        </AutoAdvance>
      else
        ()
};

(: ======================================================================
   Wrapper to call apply-reminders in run mode (by opposition to dry mode)
   ====================================================================== 
:)
declare function check:apply-reminders( $reminders as element()* ) as element()* {
  check:apply-reminders($reminders, true())
};

(: ======================================================================
   Archives a sequence of reminders into a Digest at the current date
   Overwrites existing Digest if there is already one !
   Lazily creates an YYYY-MM.xml container file in $globals:reminders-uri
   collection to group digests by month
   Returns a Digest element containing all the Reminder elements
   ======================================================================
:)
declare function check:archive-reminders( $reminders as element()*, $date as xs:dateTime ) as element()* {
  <Digest Timestamp="{ $date }">
    {
    if (xdb:collection-available($globals:reminders-uri)) then
      let $stamp := substring(string($date), 1, 10)
      let $digest := <Digest Timestamp="{ $date }">{ $reminders }</Digest>
      return
        if (empty(fn:collection($globals:reminders-uri)//Digest[starts-with(@Timestamp, $stamp)])) then
          let $filename := concat(substring(string($date), 1, 7), '.xml')
          let $host := fn:doc(concat($globals:reminders-uri, '/', $filename))/Reminders (: sharding :)
          return
            if ($host) then (
              update insert $digest into $host,
              attribute { 'Success' } { concat("New digest archive recorded on ", $date) }
              )
            else (: creates host resource :)
              let $stored-path := xdb:store($globals:reminders-uri, $filename, <Reminders>{ $digest }</Reminders>)
              return
                if(not($stored-path eq ())) then (: success :)
                  (
                  if ((xdb:get-group($globals:reminders-uri, $filename) ne 'users')
                      or (xdb:get-owner($globals:reminders-uri, $filename) ne 'admin')) then
                    compat:set-owner-group-permissions(concat($globals:reminders-uri, '/', $filename), 'admin', 'users', "rwxrwxr-x")
                  else
                    (),
                  attribute { 'Success' } { concat("New digest archive recorded on ", $date) }
                  )
                else
                  attribute { 'Warn' } { concat("Failed to record reminders digest into ", $globals:reminders-uri, '/',  $filename) }
        else (: overwrites existing digest :)
          (
          attribute { 'Warn' } { "Existing reminders digest has been overwritten" },
          update replace fn:collection($globals:reminders-uri)//Digest[starts-with(@Timestamp, $stamp)] with $digest
          )
    else
      attribute { 'Warn' } { concat("Collection ", $globals:reminders-uri, " unavailable to record reminders digest") },
    $reminders
    }
  </Digest>
};

(: ======================================================================
   Returns archived reminders Digest for given date if any or the empty sequence
   ======================================================================
:)
declare function check:get-reminders( $date as xs:date ) as element()? {
  let $stamp := substring(string($date), 1, 10)
  return
    fn:collection($globals:reminders-uri)//Digest[starts-with(@Timestamp, $stamp)]
};

(: ======================================================================
   Supervisor element implementation
   Returns the list of roles supervised by the given function references
   ======================================================================
:)
declare function check:get-roles-supervised-by( $function-refs as xs:string* ) as xs:string* {
  if (exists($function-refs)) then
    for $r in fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[Id = $function-refs]/@Role
    return 
      for $token in distinct-values(fn:doc(oppidum:path-to-config('checks.xml'))//Check[ends-with(Supervisor/Meet, $r)]/Responsible/Meet/text())
      return substring-after($token, 'r:')
  else
    ()
};
