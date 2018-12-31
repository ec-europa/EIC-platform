xquery version "1.0";
(: --------------------------------------
   SMED application

   Creator: <Franck.Leple@amplexor.com>
   Contributors: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to Create, Update and Submit a user self-registration form

   Parameters:
   - edit = save the admission in draft mode
   - edit?submit=1 = save the admission and submit it
   - edit?submit=2 = submit the admission as is

   Pre-condition: 
   - company MUST NOT already exist in SMEDashboard
   - update mapped on '/edit'

   TODO: split in two files create.xql and update.xql
 
   March 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace admission = "http://oppidoc.com/ns/application/admission" at "admission.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace system = "http://exist-db.org/xquery/system";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../../xcm/modules/users/account.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Create an investor account to identify futur access to app

   Parameters:
   - $res: result of the admission creation
   - $form: Admission form

   Pre-condition: admission form should have been saved
   ====================================================================== 
:)
declare function local:create-investor-account( $res as element()?, $form as element()? ) as element() {
  (: $res sample  <success type="create" key="3">/db/sites/cockpit/admissions/0000/3.xml</success> :) 
  let $adm := fn:doc($res/text())/Admission
  let $res2 := template:do-create-resource('self-investor', $adm, <FunctionRef>9</FunctionRef>, $form, ())
  return
    if (local-name($res2) eq 'success') then
      ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), $res/@key)
    else
      $res2
};

(: ======================================================================
   Automatique accreditation for EC Corporate users
   ====================================================================== 
:)
declare function local:do-accredit-ec-corporate($person as element(), $admission as element()?, $path as xs:string?  ) {
    if ($person/UserProfile/Blocked) then
      oppidum:throw-error('CUSTOM', 'User has already been blocked, rejected or accredited. You cannot accredit/reject/block him or her')
    else if ($admission//AdmissionStatusRef eq '1') then
      oppidum:throw-error('CUSTOM', 'User admission is in a Draft state')
    else if ($admission//AdmissionStatusRef eq '3') then
      oppidum:throw-error('CUSTOM', 'User admission is already Rejected')
    else if ($admission//AdmissionStatusRef eq '4') then
      oppidum:throw-error('CUSTOM', 'User admission is already accredited')
    else         
      let $resAddMembers := admission:add-new-member-to-enterprise($person, $admission)
      let $resRemovePendingRole :=  if (local-name($resAddMembers) eq 'success') then 
                                      admission:remove-pending-role-in-enterprise($person, $admission) 
                                    else 
                                      $resAddMembers
      return
        if (local-name($resRemovePendingRole) eq 'success') then
          let $resUR := template:do-update-resource('admission-accredit-admission', (), $admission, (), <Form/>)
          return
            if (local-name($resUR) ne 'error') then
              (:let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Settings/Teams eq 'EC']
              return:) 
                ajax:report-success-redirect('ACTION-UPDATE-SUCCESS', (), "../waitingcommunity") (:concat("../",$enterprise/Id):)
            else
              (
                template:do-update-resource('reject-admission', (), $admission, (), <Form/>)
                ,
                oppidum:throw-error('CUSTOM', concat('Automatic accreditation failed - ', $resUR))
              )
        else
          (
            template:do-update-resource('reject-admission', (), $admission, (), <Form/>)
            ,
            oppidum:throw-error('CUSTOM', concat('Automatic accreditation failed - ', $resRemovePendingRole))
          )
};


(: ======================================================================
   Validate and submit admission
   ====================================================================== 
:)
declare function local:submit-admission( $admission as element(), $form as element(), $tpl-name as xs:string, $path as xs:string? ) as element() {
  (: get updated admission for validation :)
  let $admission := fn:collection($globals:admissions-uri)//*[Id eq $admission/Id]
  let $validation := template:do-validate-resource($tpl-name, $admission, (), $form)
  return
    if (local-name($validation) ne 'valid') then
      $validation
    else
      let $resUR := template:do-update-resource('submit-admission', (), $admission, (), $form)
      return
        if (local-name($resUR) ne 'error') then
          if ($admission/isECUser eq 'yes') then
            let $person := fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/AdmissionKey eq $admission/Id]
            return
              local:do-accredit-ec-corporate($person, $admission, $path)
          else
            ajax:report-success-redirect('ACTION-UPDATE-SUCCESS', (), concat($path, $admission/Id/text()))
        else
          $resUR
};

(: ======================================================================
   Update, Update and submit or Submit Admission document
   Return Ajax protocol success or error
   Validation only on submission
   FIXME: 
   - deprecate Investor code path (no more specific investor form)
   - UPDATE related person account Email in case it has been edited !!!
   ====================================================================== 
:)
declare function local:update-admission( $admission as element(), $form as element(), $submit as xs:string ) as element() {
  let $tpl-name := if ($admission/Settings/Teams eq 'Investor') then 'admission' else 'generic-admission'
  return
    (: Update the admission, or update the admission and submit when ?submit=1 :)
    if ($submit = ('0', '1')) then
      let $res := template:do-update-resource($tpl-name, (), $admission, (), $form)
      return
        if (local-name($res) ne 'error') then (: Save & Submit :)
          if ($submit eq '1') then
            local:submit-admission($admission, $form, $tpl-name, "../")
          else
            ajax:report-success-redirect('ACTION-UPDATE-SUCCESS', (), concat("../",$admission/Id/text()))
        else
          $res
    else (: Only submit the admission when ?submit=2:)
      local:submit-admission($admission, $form, $tpl-name, ())
};

(: ======================================================================
   Create or Create and submit Admission document
   Return Ajax protocol success or error
   TODO: eventually validate Mandatory fields from a pruned version of the submitted data
   before saving to avoid the creation of a draft if not valid and user clicking Save & Submit
   ====================================================================== 
:)
declare function local:create-admission($target as xs:string, $form as element(), $submit as xs:string ) as element() {
  let $tpl-name := if ($target eq 'investors') then 'admission' else 'generic-admission'
  let $validation := <valid/>
  (: NOTE: validate only on submission - see below :)
  return
    if (local-name($validation) ne 'valid') then
      $validation
    else
      (: create admission in draft mode :)
      let $res := template:do-create-resource($tpl-name, (), (), $form, ())
      return
        if (local-name($res) eq 'success') then
          let $resAcc := local:create-investor-account($res, $form)
          return 
            if (local-name($resAcc) ne 'error') then
              if ($submit eq '1') then (: submit admission and create investor account :)
                let $admission := fn:collection($globals:admissions-uri)//.[Id eq $res/@key]
                let $valid := local:submit-admission($admission, $form, $tpl-name, ())
                return
                  if (local-name($valid) ne 'error') then (: submitted and account created :)
                    $resAcc
                  else (: draft mode and account created an validation error feedback :)
                    let $msg := oppidum:add-error('CUSTOM', $valid, true()) (: put into flash :)
                    return
                      (
                      oppidum:add-error('CUSTOM', 'Your admission form has been saved in Draft mode, however you still need to complete the registration form and to submit it in order to validate your registration.', true()),
                      response:set-status-code(201),
                      response:set-header('Location', concat($res/@key, '/edit')),
                      $valid
                      )[last()]
              else (: draft mode and account created :)
                $resAcc
            else
              $resAcc
        else
          $res
};

(: MAIN ENTRY POINT :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $form := oppidum:get-data()
let $name := $form/CompanyProfile/CompanyName
let $ent := fn:collection($globals:enterprises-uri)//Enterprise/Information[Name/text() eq $name]
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $admissionId := tokenize($cmd/@trail, '/')[2]
let $submit := request:get-parameter('submit', '0')
let $admission := fn:collection($globals:admissions-uri)//*[Id eq $admissionId]
let $profile := user:get-user-profile()
return
  if ($m = 'POST') then
    if ($target = 'edit') then
      (: update then redirect to the read-only form :)
      if (access:check-entity-permissions('update', 'Admission', $admission) and (not($profile/Blocked))) then
        if ($admission/AdmissionStatusRef = ('1', '3')) then
          local:update-admission($admission, $form, $submit)
        else
          (: FIXME: legacy admissions w/o AdmissionStatusRef have no @Date :)
          oppidum:throw-error('CUSTOM', concat("The admission has been submitted or validated since ", display:gen-display-date-time($admission/AdmissionStatusRef/@Date), " and is no more editable"))
      else
        oppidum:throw-error('FORBIDDEN', ())
    else if (empty($ent)) then
      (: create then redirect to the read-only form :)
      if ((access:check-entity-permissions('add', 'Admission')) and (not($profile/Blocked))) then
        local:create-admission($target, $form, $submit)
      else
        oppidum:throw-error('FORBIDDEN', ())
    else
      oppidum:throw-error('CUSTOM', concat("The company ", $name, " already exist and cannot be registered twice"))
  else
    oppidum:throw-error('URI-NOT-SUPPORTED', ()) 
