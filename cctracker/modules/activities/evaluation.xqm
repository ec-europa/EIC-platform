xquery version "3.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Integration with Poll application for feedback questionnaire

   Pre-requisites:
   - Poll service application running and correctly configured in config/services.xml
   - Questionnaires/SME-Feedback element correctly set in config/settings.xml
     and aligned with formulars/feedback.xml
   - SME feedback form deployed (/admin/deploy?target=services)
   - Poll service config/mapping.xml defines one entry to render the template
     for the formular named after Questionnaires/SME-Feedback in config/settings.xml

   July 2015 - (c) Copyright may be reserved
   ------------------------------------------------------------------ :)

module namespace evaluation = "http://oppidoc.com/ns/cctracker/evaluation";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/check" at "../../lib/check.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../../lib/media.xqm";
import module namespace email = "http://oppidoc.com/ns/cctracker/mail" at "../../lib/mail.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "../workflow/alert.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";

declare function local:evaluation-lazy-creation( $activity as element() ) as element() {
  if ($activity/Evaluation) then
    $activity/Evaluation
  else
    update insert element Evaluation { } into $activity
};

(: ======================================================================
   Sends e-mail to the SME Contact/KAM to respond to questionnaire
   Returns success or error message
   FIXME: hardcoded status Evaluation '8'
   TODO: use Email / Recipients model in application.xml to factorize
         eg: alert:send-and-archive("sme-feedback", $extras)
   ======================================================================
:)
declare function local:notify-contact( $order-id as xs:string, $case as element(), $activity as element(), $to as xs:string, $form as element() ) as element() {
  let $link := services:get-hook-address('cctracker.questionnaires', 'poll.form.link', $order-id)
  return
    if (empty($link)) then
        oppidum:throw-error(concat($form/@ErrPrefix, 'FEEDBACK-MISSING-LINK-CONFIG'), ())
    else if (not(check:is-email($to))) then
        oppidum:throw-error(concat($form/@ErrPrefix, 'FEEDBACK-WRONG-EMAIL'), ())
    else
      let $mail := email:render-email($form/Template/text(), $form/Template/@Lang, $case/../.., $case, $activity,
                    <var name="Link_To_Form">{ $link  }</var>
                    )
      let $from := media:gen-current-user-email(false())
      return
        let $subject := $mail/Subject
        let $content := media:message-to-plain-text($mail/Message)
        return
          if (media:send-email('workflow', $from, $to, $subject, $content)) then
          let $archive :=
            <Email>
              <To>{ $to }</To>
              { $mail/* }
            </Email>
          return (
            alert:archive($activity, $archive, (), '8', string($activity/StatusHistory/CurrentStatusRef), 'en'),
            oppidum:throw-message(concat($form/@ErrPrefix, 'FEEDBACK-EMAIL-SENT'), $to)
            )[last()]
          else
            oppidum:throw-error(concat($form/@ErrPrefix,'FEEDBACK-EMAIL-ERROR'), concat('e-mail server error sending to "', $to, '"'))
};

(: ======================================================================
   Creates an Order for an SME feedback form in the Poll service
   Sends the SME Contact an e-mail with a link to the Poll
   Saves the Order into the Evaluation document
   Returns the empty sequence, otherwise returns an error message
   The SME contact notification should throw a success message into the flash
   (full pipeline condition) to notify user that an e-mail was sent
   Rolls back the Order in case of failure
   ======================================================================
:)

declare function evaluation:launch-feedback ( $case as element(), $activity as element(), $target as xs:string) as element()? {
  let $forms := fn:doc($globals:settings-uri)/Settings/Questionnaires/Transaction[Name eq $target]/Form
  return
    (for $form in $forms
    return 
      local:launch-feedback ( $case, $activity, $target, $form)
    )[last()]  
};

(: ======================================================================
   Turns a list of variable names of a given type into a list of Variable
   elements for template rendering using application's variable definitions
   ======================================================================
:)
declare function local:gen-variables( $names as xs:string*, $type as xs:string?, $case as element(), $activity as element() ) as element()* {
  let $defs := fn:doc($globals:variables-uri)/Variables
  for $var in distinct-values($names)
  return
    if ($defs/Variable[Name eq $var]) then
      let $d := $defs/Variable[Name eq $var]
      return 
        if ($d) then
          let $res := util:eval($d/Expression/text())
          return
            <Variable Key="{ $var }">
              { 
              if ($type) then attribute { 'Type' } { $type } else (),
              string($res)
              }
            </Variable>
        else
          ()
     else
      ()
};

declare function local:launch-feedback ( $case as element(), $activity as element(), $target as xs:string, $form as element() ) as element()? {
  (: If former KAM report has been integrated into the KAM Feedback while migrating :)
  if (not($activity/Evaluation/Order[Questionnaire/text() eq $form/Name/text()])) then
    let $id := util:hash(concat($case/Information/Acronym, $form/Name/text(), current-dateTime(), string($case/Information/Summary)), "md5")
    let $secret := util:hash(concat($case/Information/Acronym, $form/Name/text(), current-dateTime(), string($activity/FundingRequest/Tasks)), "md5")
       (: 1. creates Order in Poll 3rd party service:)
    let $order :=
      <Order>
        <Id>{ $id }</Id>
        <Secret>{ $secret }</Secret>
        <Questionnaire lang="en">{ $form/Name/text() }</Questionnaire>
        {
          let $vars := fn:doc(concat('/db/www/cctracker/formulars/',$form/Template/text(),'.xml'))/Poll//Variable/@Name
          let $prefills := fn:doc(concat('/db/www/cctracker/formulars/',$form/Template/text(),'.xml'))/Poll//Prefill/@DefaultVariable
          return
            if (exists($vars) or exists($prefills)) then
              <Variables>
              {
              local:gen-variables($vars, (), $case, $activity),
              local:gen-variables($prefills, 'entry', $case, $activity)
              }
              </Variables>
            else
              ()
        }
        <Transaction>{ $target }</Transaction>
      </Order>
    let $res := services:post-to-service('poll', 'poll.orders', $order, ("200", "201"))
    return
      if (local-name($res) ne 'error') then
          (: 2. notifies SME contact of feedback form URL and archives e-mail in Activity messages :)
         let $to := string(util:eval(fn:doc($globals:variables-uri)//Variable[Name eq $form/SendTo/text()]/Expression))
         return
            let $mail := local:notify-contact($id, $case, $activity, $to, $form)
            return
              if (local-name($mail) eq 'success') then
                (: 3. saves order in Evaluation document :)
                (: lazy creation of evaluation document if processing of the very first one amongst several orders :)
                let $evaluation :=
                  if ($activity/Evaluation) then
                    $activity/Evaluation
                  else
                    update insert element Evaluation { } into $activity
                let $data :=
                  <Order>
                    {
                    $order/*,
                    <Date>{ current-dateTime() }</Date>,
                    <Email>{ $to }</Email>
                    }
                  </Order>
                let $saved-ord := update insert $data into $activity/Evaluation (:  always success :)
                return () (: success :)
              else
                (: 4. Rolls back Order in case notification e-mail could not be sent :)
                let $rollback :=
                  <Order>
                    <Id>{ $id }</Id>
                    <Cancel/>
                    <Transaction>{ $target }</Transaction>
                  </Order>
                let $res := services:post-to-service('poll', 'poll.orders', $rollback, ("200", "201"))
                return $mail
      else
        $res
  else
    ()
(: else
  oppidum:throw-error('CUSTOM', 'No SME feedback form name defined in application settings, please ask a DB administrator to fix it !') :)
};

(: ======================================================================
   Validates submitted data.
   Returns the first error found or empty sequence
   FIXME: hard coded status, hard-coded delay limit (see also alerts/checks.xml)
   ======================================================================
:)
declare function local:validate-submission ( $order as element()?, $case as element()?, $activity as element()?, $submitted as element() ) as element()* {
  if (empty($order)) then
    oppidum:throw-error('CUSTOM', concat('unkown feedback form ', $submitted/Order/Id))
  else if ($activity/StatusHistory/CurrentStatusRef eq '10') then
    oppidum:throw-error('CUSTOM', 'the activity workflow has been closed and cannot record feedback any more')
  else if ($activity/StatusHistory/CurrentStatusRef ne '8') then
    oppidum:throw-error('CUSTOM', 'the activity workflow has moved to a new status where it cannot record feedback any more')
  else if ($order/Secret ne $submitted/Secret/text()) then
    oppidum:throw-error('CUSTOM', ('authorization to save this form refused'))
  else
    ()
  (: TODO: check root element name :)
  (: eventually checks exists($activity/Evaluation) :)
};

(: ======================================================================
   Implements Assess protocol to query current status of an Order from 3rd party
   FIXME: hard-coded threshold for closing questionnaire
   ======================================================================
:)
declare function evaluation:assess-order( $submitted as element() ) as element() {
  let $order := fn:collection($globals:projects-uri)//Order[Id eq $submitted/Id/text()]
  let $case := $order/ancestor::Case
  let $activity := $order/ancestor::Activity
  let $project :=  $order/ancestor::Project
  return
    if (empty($order)) then
      oppidum:throw-error('CUSTOM', concat('unkown feedback form ', $submitted/Order/Id))
    else
      <Assess>
        <Order>
          {
          $submitted/Id,
          <CompanyName>{ $project/Information/Beneficiaries/(Coordinator|Partner)[PIC eq $case/PIC]/Name/text() }</CompanyName>,
          <ProjectName>{ $project/Information/Acronym/text() }</ProjectName>,
          if ($activity/StatusHistory/CurrentStatusRef eq '11') then (: evaluated :)
            <Closed>{ $activity/StatusHistory/Status[ValueRef eq '11']/Date/text() }</Closed>
          else if ($activity/StatusHistory/CurrentStatusRef eq '10') then  (: closed :)
            <Closed Delay="21">{ $activity/StatusHistory/Status[ValueRef eq '10']/Date/text() }</Closed>
          else if ($activity/StatusHistory/CurrentStatusRef ne '8') then  (: any other reason :)
            <Cancelled>{ $activity/StatusHistory/Status[ValueRef eq $activity/StatusHistory/CurrentStatusRef]/Date/text() }</Cancelled>
          else
            <Running/>
          }
      </Order>
    </Assess>
};

(: ======================================================================
   Check that every form involved in the same transaction have been
   already answered in order to apply transition into the workflow
   ======================================================================
:)
declare function evaluation:check-sibling-forms( $activity as element(), $trans-name as xs:string, $order-current as xs:string ) as xs:integer {
  let $trans-spec := fn:doc($globals:settings-uri)/Settings/Questionnaires/Transaction[Name/text() eq $trans-name]
  return
    count(
      for $form in $trans-spec/Form[not(Name/text() eq $order-current)]
      let $order := $activity/Evaluation/Order[Questionnaire/text() eq $form/Name/text()]
      return 
        if ($order/Answers) then
          ()
        else
          1
    )
};

(: ======================================================================
   Archive $answers into a hard-coding specifying document
   TO DO: Add spec to proxies.html ?
   NOTE: actually does not overwrite FinalReportApproval, this should not 
   be a problem since it is called when entering a final state Evaluated
   ======================================================================
:)
declare function evaluation:archive_answers( $answers as element(), $activity as element() )
{
  if (count($activity/FinalReportApproval/*[not(local-name(.) = ('Tools','Profiles','Recognition','CoachingAssistantVisa','CoachingManagerVisa'))][count(child::*) ge  1]) gt 0) then
    ()
  else
    let $fra :=
      if ($activity/FinalReportApproval) then
        ()
      else
        update insert <FinalReportApproval/> into $activity
    return
      let $suplist := ('Dialogue', 'PastRegionalInvolvement', 'RegionalInvolvement', 'FutureRegionalInvolvement', 'FutureSupport', 'Dissemination')
      return
        for $ans in $answers/*[not(local-name(.) = ('Comment','ContactEmail'))]
        let $idx := substring($ans/@For,string-length($ans/@For)-1)
        let $n := number($idx)
        return
          let $elt := element { $suplist[$n - 3] }
          { 
            element { local-name($ans) } { $ans/text() },
            $answers/*[local-name(.) eq 'Comment'][ends-with(./@For, $idx)]
          }
          return update insert $elt into $activity/FinalReportApproval 
};

(: ======================================================================
   Handles 3rd party feedback questionnaire submission
   FIXME: hard coded status '8', '11'
   ======================================================================
:)
declare function evaluation:submit-answers( $submitted as element() ) as element() {
  let $order := fn:collection($globals:projects-uri)//Order[Id eq $submitted/Id/text()]
  let $case := $order/ancestor::Case
  let $activity := $order/ancestor::Activity
  let $project:= $case/ancestor::Project
  let $errors := local:validate-submission($order, $case, $activity, $submitted)
  return
    if (empty($errors)) then (
      (: triggers Activity workflow transition and e-mail notification :)
      if ($order/Questionnaire/text() eq 'cctracker-kam-feedback') then
        evaluation:archive_answers($submitted/Answers, $activity)
      else
        (),
     misc:save-content($order, $order/Answers, $submitted/Answers),
     let $omitted := evaluation:check-sibling-forms( $activity, $order/Transaction/text(), $order/Questionnaire/text() )
     return
       if ($omitted = 0) then
         (: let $transition := workflow:get-transition-for('Activity', '8', '11') :)
         let $result := workflow:apply-transition-to('11', $project, $case, $activity)
         return
            if (empty($result)) then (: status changed to Evaluated :)
              let $success := oppidum:throw-message('INFO', 'Your answers have been recorded, thank you for your contribution')
              return
                let $dummy-transition := (: FIXME: move to application.xml with @Mode="invisible" :)
                  <Transition From="8" To="11" Mail="direct">
                    <Meet>all</Meet>
                    <Recipients>g:coaching-manager</Recipients>
                  </Transition>
                return workflow:apply-notification('Activity', $success, $dummy-transition, $project, $case, $activity)
            else
              $result
       else
         let $success := oppidum:throw-message('INFO', 'Your answers have been recorded, thank you for your contribution')
         return $success
      )[last()]
    else
      $errors
};

(: ======================================================================
   Creates and sends an Order to close an SME feedback form in the Poll service
   Returns either a flash-ed message or the empty sequence since the outcome 
   should be non-blocking (see status.xql)
   ======================================================================
:)
declare function evaluation:close-feedback ( $case as element(), $activity as element(), $target as xs:string) as element()? {
  let $forms := fn:doc($globals:settings-uri)/Settings/Questionnaires/Transactions[Name eq $target]/Form
  return
    for $form in $forms
    let $order := $activity/Evaluation/Order[Questionnaire/text() eq $form/text()]
    return
      if ($order) then
        let $submit :=
            <Order>
              { $order/Id }
              <Close/>
            </Order>
        let $res := services:post-to-service('poll', 'poll.orders', $submit, "200")
        return (
          update insert <Closed>{ current-dateTime() }</Closed> into $order,
          (: directly adds message to the flash since this method is called from the 'status' command
             which replies with an Ajax response and otherwise would immediately render the messages :)
          if (local-name($res) ne 'error') then
            oppidum:add-message('INFO', concat('The "', $order/Questionnaire/text() ,'" feedback questionnaire has been closed on the poll application'), true())
          else
            oppidum:add-message('INFO', concat('The "', $order/Questionnaire/text() ,'" feedback questionnaire could not be closed on the poll application because ', $res//message), true())
          )
      else
        ()
};
