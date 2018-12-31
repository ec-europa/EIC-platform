xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Automatic Case assignation utility

   Handles both GET / POST to overview reminding cases / trigger assignment
   Uses an iterative pattern that fills the stash with success and error message
   for each case, and redirects to the overview at the end
   Default user signature and sender e-mail address stored in settings.xml
   otherwise they default to current user

   April 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace assign = "http://oppidoc.com/ns/cctracker/assign" at "assign.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "../workflow/alert.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../../lib/media.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/check" at "../../lib/check.xqm";

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $submitted as element(), $call as xs:string, $nb as xs:integer ) as element()* {
  let $max := count(collection($globals:projects-uri)/Project[Information/Call[(SMEiCallRef, FETCallRef, FTICallRef) = $call]][count(Cases/Case[PIC ]) ne count(../Beneficiaries/PIC) or not(Cases/Case/ManagingEntity/RegionalEntityRef)])
  let $errors := (
    if (($nb > 20)) then
      oppidum:throw-error('CUSTOM', ('The number of cases to assign has been limited to a maximum of 20 while testing this new functionality'))
    else if (($nb < 1) or ($nb > $max)) then
      oppidum:throw-error('VALID-INTEGER-INTERVAL', ('1', string($max)))
    else if (not(check:is-email($submitted/From/text()))) then
      oppidum:throw-error('INVALID-EMAIL', ('From'))
    (: FIXME : check FirstName and LastName in case of POST forgery... :)
    else
      ()
    )
  return $errors
};

(: ======================================================================
   Utility to return variables representing current user name for batch
   Looks up if some default signature is defined in settings.xml
   otherwise returns current user name
   ======================================================================
:)
declare function local:gen-batch-user-name() as element()* {
  let $sig := fn:doc($globals:settings-uri)/Settings/Batch/DefaultEmailSignature
  return
    if ($sig) then (
      <var name="User_First_Name">{ $sig/FirstName/text() }</var>,
      <var name="User_Last_Name">{ $sig/LastName/text() }</var>
      )
    else
      alert:gen-current-user-name()
};

(: ======================================================================
   Returns the e-mail address to be used as the sender
   Looks up if some default email address is defined in settings.xml
   otherwise returns current user e-mail address
   ======================================================================
:)
declare function local:gen-batch-sender() as xs:string {
  let $sig := fn:doc($globals:settings-uri)/Settings/Batch/DefaultEmailReplyTo
  return
    if ($sig) then
      $sig/text()
    else
      media:gen-current-user-email(false())
};

(: ======================================================================
   Generates an informative "Undefined Call" message
   TODO: factorize with export/cases.xql (calls.xqm ?)
   ======================================================================
:)
declare function local:error-msg ( $target as xs:string ) as xs:string {
  concat('Undefined Call "', $target, '"', ' known Calls are : ',
    string-join(
      for $o at $i in fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'CallRollOuts']/Option
      return concat('"', $i, '"', ' (', $o/Date/text(), ' Phase ', $o/PhaseRef/text(), ')'),
      ", "
      )
    )
};

(: ======================================================================
   Converts target token to (Call, PhaseRef) pair of strings or "Undefined Call"
   TODO: factorize with export/cases.xql (calls.xqm ?)
   ======================================================================
:)
declare function local:get-call( $target as xs:string ) as xs:string* {
  if (matches($target, '^\d+$')) then
    let $spec := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'CallRollOuts']/Option[number($target)]
    return
      if ($spec) then
        ($spec/Date/text(), $spec/PhaseRef/text())
      else
        local:error-msg($target)
  else
    local:error-msg($target)
};

(: ======================================================================
   Returns a 'Surname Name (email)' list of persons with an wrong email
   ======================================================================
:)
declare function local:filter-by-email( $persons as element()* ) as xs:string* {
  for $p in $persons
  let $m := $p/Contacts/Email/text()
  where not(check:is-email($m))
  return
    concat(upper-case($p/Name/LastName), ' ', $p/Name/FirstName, ' (', if (string-length(string($m)) eq 0) then 'no e-mail' else $m, ')')
};

(: ======================================================================
   Returns a 'Surname Name' list of persons without a user account name
   ======================================================================
:)
declare function local:filter-by-login( $persons as element()* ) as xs:string* {
  for $p in $persons
  where not($p//Remote[@Name = 'ECAS']) and not($p//Username) and ($p//Username eq '')
  return
    concat(upper-case($p/Name/LastName), ' ', $p/Name/FirstName)
};

(: ======================================================================
   Sends and archives notification message to the EEN KAM Coordinator(s)
   of the region for the case. Since it is called before assignment 
   it has to compute "manually" recipients list.
   
   Returns a success or an error element with an explanation text

   TODO:
   - create a separate 'debug' category for debug (instead of 'workflow')

   FIXME:
   - function reference '3' and status names '1', '2' hard-coded
   ======================================================================
:)
declare function local:notify-coordinator( $case as element(), $match as element(), $submitted as element() ) as element() {
  let $targets := fn:collection($globals:persons-uri)//Person[.//Role[(FunctionRef eq '3') and (RegionalEntityRef eq $match/Id/text())]]
  let $no-email := local:filter-by-email($targets)
  let $no-login := local:filter-by-login($targets)
  let $recipients := $targets/Id/text()
  let $total := count($recipients)
  return
    if (count($no-email) > 0) then
      <error>you must enter a valid e-mail address for { string-join($no-email, ' and ') }</error>
    else if (count($no-login) > 0 ) then
      <error>you must create a login for { string-join($no-login, ' and ') }</error>
    else if ($total eq 0) then
      <error>no EEN KAM Coordinator for the entity</error>    
    else
      let $mail :=
        media:render-alert('een-coordinator-notification',
          <vars>
            <var name="EEN_Entity">{ display:gen-name-for-regional-entities( $match/Id, 'en') }</var>
            <var name="User_First_Name">{ $submitted/FirstName/text() }</var>
            <var name="User_Last_Name">{ $submitted/LastName/text() }</var>
            { alert:gen-case-activity-title($case, ()) }
            { alert:gen-link-to-case-activity($case, ()) }
            { alert:gen-user-name-for('Coordinator', $recipients) }
          </vars>,
          'en'
          )
      let $from := $submitted/From/text()
      return
        let $res := alert:send-email-to('workflow', $from, $recipients, (), $mail)
        return
          if (($total eq 0) or (count($res[local-name(.) eq 'error']) < $total)) then (: succeeded for at list one recipient => archives it :)
            let $alert := (: constructs model for saving :)
              <Alert Mode="batch">
                <Addressees>
                  {
                  for $ref in $recipients
                  return <AddresseeRef>{ $ref }</AddresseeRef>
                  }
                </Addressees>
                <From>{ $from }</From>
                { $mail/* }
              </Alert>
            let $archive := alert:archive($case, $alert, (), '2', '1','en')
            return
              <success>{ string-join($res, ", ") }</success>
          else
            <error>{ string-join($res,', ') }</error>
};

(: ======================================================================
   FIXME: assigned status '2' hard coded (MUST be synch with application.xml)
   Note: local:notify-coordinator duplicates more or less alert:notify-transition
   but we can't factorize since we want to change status if and only if we can 
   manage to send email to coordinator first (notification preceeds 
   transition in that case)
   ======================================================================
:)
declare function local:assign-case( $case as element(), $match as element(), $submitted as element() ) {
  let $res := local:notify-coordinator($case, $match, $submitted)
  return
    if (local-name($res) eq 'success') then (
      let $data :=
        <ManagingEntity>
          <RegionalEntityRef>{ $match/Id/text() }</RegionalEntityRef>
          <AssignedByRef>batch</AssignedByRef>
          <Date>{ current-dateTime() }</Date>
        </ManagingEntity>
      return
        misc:save-content($case, $case/ManagingEntity, $data),
      let $err := workflow:apply-transition-to('2', $case/../.., $case, ())
      return
        if (empty($err)) then
          oppidum:add-message('CASE-ASSIGNED', ($case/../../Information/Acronym/text(), $match/Acronym/text(), $res/text()), true())
        else
          oppidum:add-error('CASE-NOT-ASSIGNED', ($case/../../Information/Acronym/text(), $match/Acronym/text(), 'impossible to write new status'), true())
      )
    else (: does not change status if mail notification not sent :)
      oppidum:add-error('CASE-NOT-ASSIGNED', ($case/../../Information/Acronym/text(), $match/Acronym/text(), $res/text()), true())
};

declare function local:gen-case-for-writing( $index as xs:integer, $pic as element() ) {
  let $now := current-dateTime()
  let $date :=  substring(string($now),1,10)
  let $year := substring($date, 1, 4)
  return
    <Case>
      <No>{ $index }</No>
      { $pic }
      <CreationDate>{ $date }</CreationDate>
      <StatusHistory>
        <CurrentStatusRef>1</CurrentStatusRef>
        <Status>
          <Date>{ $date }</Date>
          <ValueRef>1</ValueRef>
        </Status>
      </StatusHistory>
    </Case>
};

declare function local:bootstrap-cases( $project as element()?, $coord as xs:boolean )  {
  if ($project) then
    let $weird := update delete $project/Cases/Case[not(PIC)]
    return
    let $cases := $project/Cases
    let $todo :=
       if ($coord) then
         $project/Information//Coordinator/PIC[not(. = $cases//PIC)]
       else
         ($project/Information/Beneficiaries/(Coordinator | Partner)/PIC[not(. = $cases//PIC)])[1]
    return
      if ($cases) then (: simple insertion into list :)
        if ($todo) then
          let $index :=
            if ($cases/@LastIndex castable as xs:integer) then
              number($cases/@LastIndex) + 1
            else (: unlikely :)
              1
          let $case := local:gen-case-for-writing($index, $todo)
          return
            let $updates :=
              (
              update insert $case into $cases,
              update value $cases/@LastIndex with $index
              )
            return local:bootstrap-cases( $project, $coord )
        else
          ()
      else (: first one, creation of list :)
        let $case := local:gen-case-for-writing( 1, $todo )
        let $cases :=
          <Cases LastIndex="1">
            { $case }
          </Cases>
        return
          let $update := update insert $cases into $project
          return local:bootstrap-cases( $project, $coord )
  else
    ()
};

(: ======================================================================
   Assigns the head case if it can be assigned and iterates on the next one
   Stops when max cases have been assigned
   Accumulate success and error for each case into the stash
   ======================================================================
:)
declare function local:assign-cases( $head as element()?, $reminder as element()*, $done as element()*, $max as xs:integer, $submitted as element(), $coord as xs:boolean ) {
  let $bootstrap := local:bootstrap-cases( $head, $coord )
  return
  if (empty($head) or (count($done) >= $max)) then
    ajax:report-success-redirect('COMMAND-TERMINATED', (), 'assign')
  else
    for $case in collection('/db/sites/cctracker/projects')/Project[Id eq $head/Id]/Cases/Case[not(ManagingEntity)]
    let $match := assign:suggest-region($case, 'en')
    return
      if ((local-name($match[1]) ne 'error') and (count($match) eq 1)) then (: can be assigned :)
        (
        local:assign-case($case, $match, $submitted),
        local:assign-cases($reminder[1], subsequence($reminder, 2), ($done, $head), $max, $submitted, $coord)
        )
      else (: cannot be assigned :)
        local:assign-cases($reminder[1], subsequence($reminder, 2), $done, $max, $submitted, $coord)
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $call := string($cmd/resource/@name)
let $testing := request:get-parameter-names() = 'test'
return
  if ($m eq 'POST') then
      let $data := oppidum:get-data()
    let $nb := if ($data/Number castable as xs:integer) then xs:integer($data/Number) else -1
    let $errors := local:validate-submission($data, $call, $nb)
    let $coord := exists($data//Coordinator)
    return
      if (empty($errors)) then
        let $stack :=
          for $p in collection('/db/sites/cctracker/projects')/Project[Information/Call[(SMEiCallRef, FETCallRef, FTICallRef) = $call]]
          let $needs := $p/Information/Beneficiaries/(Coordinator | Partner)/PIC
            where(
              not($coord) and (
                count($p/Cases/Case[PIC = $needs]) ne count($needs)
                or ((some $ref in $needs satisfies (not($p/Cases/Case[PIC eq $ref][ManagingEntity/RegionalEntityRef]) )))))
              or (not( $p/Cases/Case[PIC = $needs][ManagingEntity/RegionalEntityRef]) )
          return $p
        return local:assign-cases($stack[1], subsequence($stack, 2), (), $nb, $data, $coord)[last()]
      else
        ajax:report-validation-errors($errors)
  else
    if (starts-with($call, 'Undef')) then
      <Error>{ $call }</Error>
    else
      let $type := fn:collection($globals:global-info-uri)//Selector[@Name = ('SMEiCalls','FETCalls', 'FTICalls')]/Group[Selector/Option[Code eq $call]]/Type
      let $date := fn:collection($globals:global-info-uri)//Selector[@Name = ('SMEiCalls','FETCalls', 'FTICalls')]/Group/Selector/Option[Code eq $call]/Date
      let $name := fn:collection($globals:global-info-uri)//Selector[@Name = ('SMEiFundings', 'FETActions')]/Option[Code eq $type]/Name
      let $sel := fn:collection($globals:global-info-uri)//Selector[Group/Selector/Option[Code eq $call]]/@Name
      return
      <Cases Call="{ $call }" CallDate="{ $date }" Phase= "{ $name }" Base="../.." User="{ misc:gen-current-person-name() }" Date="{ substring(string(current-dateTime()), 1, 19) }">
        <Settings>
          <DefaultEmailReplyTo>{ local:gen-batch-sender() }</DefaultEmailReplyTo>
          <DefaultEmailSignature>
          {
          let $sig := local:gen-batch-user-name()
          return (
            <FirstName>{ $sig[./@name eq 'User_First_Name']/text() }</FirstName>,
            <LastName>{ $sig[./@name eq 'User_Last_Name']/text() }</LastName>
            )
          }
          </DefaultEmailSignature>
        </Settings>
        {
        for $project in collection($globals:projects-uri)/Project[Information/Call[(SMEiCallRef, FETCallRef, FTICallRef) = $call]]
        return
          for $benef in $project/Information/Beneficiaries/(Coordinator|Partner)
          let $case := $project/Cases/Case[PIC eq $benef/PIC]
          let $region := if ($case) then $case/ManagingEntity/RegionalEntityRef else ()
          return
            <Case>
              { if ($case) then attribute CaseNo {$case/No} else () }
              { $project/Id }
              <PIC>{$benef/Name} ({$benef/PIC/text()})</PIC>
              { $project/Information/Acronym }
              { 
              if (not($testing)) then
                if ($case/StatusHistory/CurrentStatusRef eq '9') then 
                  <Hold/>
                else if ($case/StatusHistory/CurrentStatusRef eq '10') then 
                  <NoCoaching/>
                else
                  ()
              else
                ()
              }
              {
              if ($region and not($testing)) then (: already assigned :)
                <EEN>
                  <Name>
                    {
                      fn:collection($globals:regions-uri)//Region[Id eq $region]/Acronym/text()
                    }
                  </Name>
                </EEN>
              else (: automatic assignment simulation :)
                let $match :=
                  if (empty($case)) then
                    assign:suggest-region-from-enterprise($benef, 'en')
                  else
                    assign:suggest-region($case, 'en')
                return
                  if (local-name($match[1]) eq 'error') then
                  $match
                else
                  for $een in $match
                  return
                    <EEN Ref="{ $een/Id/text() }">
                      { 
                        if (exists($region)) then
                          attribute { 'Test' } { if ($region eq $een/Id) then 'ok' else 'nok' }
                        else
                          ()
                      }
                      <Name>{ $een/Acronym/text() }</Name>
                    </EEN>
            }
          </Case>
        }
      </Cases>
