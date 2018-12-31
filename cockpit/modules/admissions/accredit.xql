xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   POST Controller to <Accredit/>, <Reject/> or <Block/> one Team Member

   Acts on (Person, Member) pair

   To be called from search.xql results table

   Implements Ajax JSON table protocol for "members" table rows (see also search.[xql, xql])

   May 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace admission = "http://oppidoc.com/ns/application/admission" at "admission.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace search = "http://oppidoc.com/ns/application/search" at "../teams/search.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare option exist:serialize "method=json media-type=application/json";

declare variable $local:vocabulary := ('accredit', 'accredit-all', 'reject', 'reject-all', 'block', 'unreject', 'unreject-all', 'unblock');
declare variable $local:protected := ('reject', 'block', 'unreject', 'unblock');

(: ======================================================================
   DEPRECATED - Create the new investor enterprise from the investor auto registration form
   Update user account (Person collection - changing Role)
   Parameters:
   - $admission : the admission form
   - $person : The account create when the form was submitted   
   ======================================================================
:)
declare function local:create-new-investor-enterprise($person as element(), $admission as element()) {
  (: test if a company for this pending investor already exist :)
  (: Create investor company and add the investor as a member :)
  (: TODO : Test if the company already exist:)
  let $resEnterprise := template:do-create-resource('self-investor-company', $person, $admission, <Form/>,())
  (: Update the investor account (person) in order to add the EnterpriseRef and change his Role 
     First step: Get the Enterprise
     Second step: Update the Enterprise for the Berlin-2018 event
     Third step: Update the investor account :)
   return
   if (local-name($resEnterprise) eq 'success') then
   (
      let $newEntrepriseId := $resEnterprise/@key
      let $newEntreprise :=  globals:collection('enterprises-uri')//Enterprise[Id/text() eq $newEntrepriseId]
      let $resInvestor :=  template:do-update-resource('self-investor', $person/Id, $newEntreprise, $person, <Form/>)
      return
      if (local-name($resInvestor) eq 'success') then
       (: Update the Admission and Accredited it 
          Generate the table row :)
       admission:gen-ajax-response(
          template:do-update-resource('accredit-admission', (), $admission, $person, <Form/>),
          $person, $admission, 'investors'
          )
      else
          oppidum:throw-error('CUSTOM', concat("Accreditation failed - Investor ", $person/Id, " accreditation failed"))
     )
     else
       oppidum:throw-error('CUSTOM', concat("Accreditation failed - Company ", $admission/CompanyProfile/CompanyName/text(), " creation failed"))
};

(: ======================================================================
   Create the new enterprise from the user auto registration form
   Update user account (Person collection - adding Role)
   Parameters:
   - $admission : the admission form
   - $person : The account create when the form was submitted
   Return <success/> or <error>string</error>
   ======================================================================
:)
declare function local:create-new-generic-enterprise($person as element(), $admission as element()) {
  (: Create the new enterprise $admission/CreateOrganisation/OrganisationInformation/Name :)
  if (exists($admission/CreateOrganisation/OrganisationInformation)) then
    let $resEnterprise := template:do-create-resource('generic-company', $person, $admission, <Form/>,())
    return
      if (local-name($resEnterprise) eq 'success') then
        (
        let $newEntrepriseId := $resEnterprise/@key
        let $newEntreprise :=  globals:collection('enterprises-uri')//Enterprise[Id/text() eq $newEntrepriseId]
        (: accredit user in new company as a LEAR/Investor - TODO: will be "Account owner" as per SMEIMKT-1119 :)
        let $resUser :=  template:do-update-resource('user-account-join-new-company', $person/Id, $newEntreprise, $person, $admission)
        return
          if (local-name($resUser) eq 'success') then
            $resUser
          else
            <error>{ concat("User ", $person/Id, " accreditation failed [", string($resUser), "]") }</error>
        )
     else
       <error>{ concat("Company ", $admission/CompanyProfile/CompanyName, " creation failed [", string($resEnterprise), "]") }</error>
  else (: pass through :)
    <success/>
};

(: ======================================================================
   Implements accreditation controller POST request
   ======================================================================
:)
declare function local:do-accredit( $goal as xs:string, $person as element(), $admission as element()? ) {
   if ($goal eq 'accredit') then (: applies 'accredit-delegate' template :)
    (
        (: DEPRECATED - USED FOR THE INVESTOR SELF-REGISTRATION :)
        if ($person/UserProfile/Blocked) then
          oppidum:throw-error('CUSTOM', 'User has already been blocked, rejected or accredited. You cannot accredit/reject/block him or her')
        else if ($admission//AdmissionStatusRef eq '1') then
          oppidum:throw-error('CUSTOM', 'User admission is in a Draft state')
        else if ($admission//AdmissionStatusRef eq '3') then
          oppidum:throw-error('CUSTOM', 'User admission is already Rejected')
        else if ($admission//AdmissionStatusRef eq '4') then
          oppidum:throw-error('CUSTOM', 'User admission is already accredited')
        else   
           local:create-new-investor-enterprise($person, $admission)
      )
   else if ($goal eq 'accredit-all') then 
     (
        if ($person/UserProfile/Blocked) then
          oppidum:throw-error('CUSTOM', 'User has already been blocked, rejected or accredited. You cannot accredit/reject/block him or her')
        else if ($admission//AdmissionStatusRef eq '1') then
          oppidum:throw-error('CUSTOM', 'User admission is in a Draft state')
        else if ($admission//AdmissionStatusRef eq '3') then
          oppidum:throw-error('CUSTOM', 'User admission is already Rejected')
        else if ($admission//AdmissionStatusRef eq '4') then
          oppidum:throw-error('CUSTOM', 'User admission is already accredited')
        else   
          let $resCreation := local:create-new-generic-enterprise($person, $admission)
          let $resAddMembers :=  if (local-name($resCreation) eq 'success') then 
                                   admission:add-new-member-to-enterprise($person, $admission)
                                 else
                                   $resCreation 
          let $resRemovePendingRole :=  if (local-name($resAddMembers) eq 'success') then 
                                          admission:remove-pending-role-in-enterprise($person, $admission) 
                                        else 
                                          $resAddMembers
          return
            if (local-name($resRemovePendingRole) eq 'success') then
              admission:gen-ajax-response(
                      template:do-update-resource('admission-accredit-admission', (), $admission, (), <Form/>),
                      $person, $admission, 'entries'
                      ) 
            else
              oppidum:throw-error('CUSTOM', concat('Accreditation failed - ', $resRemovePendingRole))
     )
   else if ($goal eq 'block') then (: applies 'block-investor' template :)
       if ($person/UserProfile/Blocked) then
           oppidum:throw-error('CUSTOM', 'User has already been blocked, rejected or accredited. You cannot accredit/reject/block him or her')
       else
           admission:gen-ajax-response(
           template:do-update-resource(concat($goal, '-investor'), (), $person, $admission, <Form/>),
           $person, $admission, 'entries'
     )
   else if ($goal eq 'unblock') then (: applies 'unblock-investor' template :)
       if (not($person/UserProfile/Blocked)) then
           oppidum:throw-error('CUSTOM', 'User has not been blocked. You cannot unblock him or her')
       else
           admission:gen-ajax-response(
           template:do-update-resource(concat($goal, '-investor'), (), $person, $admission, <Form/>),
           $person, $admission, 'entries'
     )
    else if ($goal eq 'unreject') then (: applies 'unreject-admission' template :)
     if (not($admission//AdmissionStatusRef eq '3')) then
         oppidum:throw-error('CUSTOM', 'User admission is not Rejected')
     else
        admission:gen-ajax-response(
        template:do-update-resource(concat($goal, '-admission'), (), $admission, $person, <Form/>),
        $person, $admission, 'investors'
     )
   else if ($goal eq 'reject-all') then (: applies 'reject-all-admission' template :)
     if ($admission//AdmissionStatusRef eq '3') then
         oppidum:throw-error('CUSTOM', 'User admission is already Rejected')
     else
        admission:gen-ajax-response(
        template:do-update-resource(concat($goal, '-admission'), (), $admission, $person, <Form/>),
        $person, $admission, 'entries'
     )
   else if ($goal eq 'unreject-all') then (: applies 'unreject-all-admission' template :)
     if (not($admission//AdmissionStatusRef eq '3')) then
         oppidum:throw-error('CUSTOM', 'User admission is not Rejected')
     else
        admission:gen-ajax-response(
        template:do-update-resource(concat($goal, '-admission'), (), $admission, $person, <Form/>),
        $person, $admission, 'entries'
     )  
   else (: applies 'reject-admission' template :)
     if ($admission//AdmissionStatusRef eq '3') then
         oppidum:throw-error('CUSTOM', 'User admission is already Rejected')
     else
        admission:gen-ajax-response(
        template:do-update-resource(concat($goal, '-admission'), (), $admission, $person, <Form/>),
        $person, $admission, 'investors'
     )
};

(:*** ENTRY POINT - unmarshalling - access control - validation ***:)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $person-id := tokenize($cmd/@trail, '/')[3]
let $current-userid := user:get-current-person-id()
let $person := fn:collection($globals:persons-uri)//Person[Id/text() eq string($person-id)]
let $admission := fn:collection($globals:admissions-uri)//.[Id eq $person//AdmissionKey[parent::Role[FunctionRef eq '9']][1]]
let $submitted := oppidum:get-data()
let $goal := lower-case(local-name($submitted))
return
  if (($m = 'POST') and ($goal = $local:vocabulary) and exists($person)) then
    if ($current-userid eq $person/Id and $goal = $local:protected) then
      oppidum:throw-error('CUSTOM', concat('You cannot ', $goal, ' yourself'))
    else if (access:check-entity-permissions($goal, 'Admission')) then
      try {
        local:do-accredit($goal, $person, $admission)
      }
      catch * {
        let $msg := string(concat('Accreditation process failed - error ', string($err:description/text()), ' ', string($err:value/text())))
        return
          oppidum:throw-error('CUSTOM', $msg)
      }
    else
      oppidum:throw-error('FORBIDDEN', ())
  else
    oppidum:throw-error('URI-NOT-FOUND', ())
