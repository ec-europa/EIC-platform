xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Utility functions related to Company profile
   Includes ScaleupEU web service implementation

   Authors: 
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>
   - Stéphane Sire <s.sire@oppidoc.fr>

   May 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace enterprise = "http://oppidoc.com/ns/enterprise";

import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

(: ======================================================================
   Helper function to generate service Category payload
   ====================================================================== 
:)
declare function local:get-category( $enterprise as element() ) as xs:string {
  if (enterprise:is-a($enterprise, 'Investor')) then 
    'investor'
  else
    'beneficiary'
};

(: ======================================================================
   Helper function to generate EULogin service payload
   DEPRECATED: not used on Scaleup ? 
   ====================================================================== 
:)
declare function local:get-contact-eu-login( $member as element() ) as element()? {
  let $eu-login := fn:collection($globals:persons-uri)//Person[Id eq $member/PersonRef]/UserProfile/Remote[@Name eq 'ECAS']
  return
    if (exists($eu-login)) then
      <EULogin>{ $eu-login/text() }</EULogin>
    else
      ()
};

(: ======================================================================
   Returns all enterprises with current logged user as member
   ======================================================================
:)
declare function enterprise:get-my-enterprises() as element()* {
  let $pref := user:get-current-person-id ()
  return
    globals:collection('enterprises-uri')//Enterprise[Team//PersonRef[text() eq $pref]]
};

(: ======================================================================
   Returns all valid enterprises with current logged user as member 
   ====================================================================== 
:)
declare function enterprise:get-my-valid-enterprises() as element()* {
  let $pref := user:get-current-person-id ()
  return
    globals:collection('enterprises-uri')//Enterprise[Team//Member[PersonRef eq $pref]][empty(Status/StatusFlagRef) or Status/StatusFlagRef eq '2']
};

(: ======================================================================
   Returns the total number of enterprises with current logged user as member
   independently of their status (valid or not)
   ======================================================================
:)
declare function enterprise:count-my-enterprises() as xs:integer {
  let $pref := user:get-current-person-id ()
  return
    count(globals:collection('enterprises-uri')//Enterprise/Team//PersonRef[text() eq $pref])
};

(: ======================================================================
   Returns true() if an enterprise is validated by REA false() otherwise
   See also: access rules in application.xml
   ======================================================================
:)
declare function enterprise:is-valid( $enterprise as element() ) as xs:boolean {
  let $status := $enterprise/Status/StatusFlagRef
  let $type := $enterprise/ValidationStatus/CompanyTypeRef
  return
    (empty($status) or $status eq '2') and (empty($type) or $type ne '2')
};

(: ======================================================================
   Returns true() if an enterprise has at least one on-going project
   or if it is an Investor company
   See also: access rules in application.xml
   ======================================================================
:)
declare function enterprise:has-projects( $enterprise as element() ) as xs:boolean {
  enterprise:is-a($enterprise, 'Investor')
  or
  (some $p in $enterprise/Projects/Project satisfies (:($p/GAP/CommissionSignature ne '') 
    and:) (empty($p/TerminationFlagRef) or ($p/TerminationFlagRef eq ''))
  )
};

(: ======================================================================
   Returns if the company has at least one ongoing project
   ======================================================================
:)
declare function enterprise:list-valid-projects( $id as xs:string ) as element()* {
  for $proj in globals:collection('enterprises-uri')//Enterprise[Id/text() eq $id]/Projects/Project
  where ((:$proj/GAP/CommissionSignature and :)not($proj/TerminationFlagRef) or ($proj/TerminationFlagRef eq ''))
  return $proj
};

(: ======================================================================
   Returns if the company has at least one ongoing project
   ======================================================================
:)
declare function enterprise:has-some-valid-projects( $id as xs:string ) as xs:boolean {
  some $proj in globals:collection('enterprises-uri')//Enterprise[Id/text() eq $id]/Projects/Project satisfies ((:$proj/GAP/CommissionSignature and:) not($proj/TerminationFlagRef) or ($proj/TerminationFlagRef eq ''))
};

(: ======================================================================
   Returns the path to the unique valid enterprise or to the switch page 
   if several appear. Returns a relative path.
   ======================================================================
:)
declare function enterprise:default-redirect-to( $prefix as xs:string? ) as xs:string {
  let $prefix := if ($prefix) then concat($prefix,'/') else ''
  let $pref := user:get-current-person-id ()
  let $es := enterprise:get-my-valid-enterprises()
  return
    if (count($es) > 1) then
      'switch'
    else
      concat($prefix, $es/Id)
};

(: ======================================================================
   Returns true() if an enterprise belongs to a given category
   ======================================================================
:)
declare function enterprise:is-a( $enterprise as element(), $category as xs:string ) as xs:boolean {
  if (($category ne 'Investor') and ($category ne 'Beneficiary')) then
    exists($enterprise/Settings/Teams) and  $enterprise/Settings/Teams eq $category
  else if ($category eq 'Investor') then
    if ($enterprise/Settings/Teams/text() eq $category) then
      true()
    else if ($enterprise/@AdmissionKey) then (: DEPRECATED ? :)
      let $admKey := $enterprise/@AdmissionKey
      let $admission := fn:collection($globals:admissions-uri)//Admission[Id eq $enterprise/@AdmissionKey]
      return
       if ($admission/MyOrganisationProfile/MyOrganisationsTypes/MyOrganisationsTypeRef[text() eq '61']) then
        true()
       else
        false()
    else
      false()
  else if ($category eq 'Beneficiary') then
   if ($enterprise/Settings/Teams/text() eq 'Investor') then
      false()
   else
    if ($enterprise/Settings/Teams/text() eq $category) then (: TO BE REMOVED : dead code, flag never set ? :)
      true()
    else if ((empty($enterprise/ValidationStatus/CompanyTypeRef[text()])) or ($enterprise/ValidationStatus/CompanyTypeRef = '1')) then
      true()
    else if ($enterprise/@AdmissionKey) then (: TO BE REMOVED : dead code ? registration form does not allow it ? :)
      let $admKey := $enterprise/@AdmissionKey
      let $admission := fn:collection($globals:admissions-uri)//Admission[Id eq $enterprise/@AdmissionKey]
      return
       if ($admission/MyOrganisationProfile/MyOrganisationsTypes/MyOrganisationsTypeRef[text() eq '60']) then
        true()
       else
        false()
    else
    false()    
  else
    false()
};
(: ======================================================================
   Returns organisationType of an enterprise 
   ======================================================================
:)
declare function enterprise:organisationType( $ref as xs:string) as xs:string {
   let $enterprise := globals:collection('enterprises-uri')//Enterprise[Id = $ref]
   return
   if (exists($enterprise/Settings/Teams)) then
        if($enterprise/Settings/Teams eq 'Investor') then
          let $admKey := $enterprise/@AdmissionKey
          return
            if (exists($admKey)) then (:investor created by auto admission:)
              let $admission := fn:collection($globals:admissions-uri)//Admission[Id eq $enterprise/@AdmissionKey]
              return
                if(exists($admission)) then
                  enterprise:organisationTypeFromAdmission($admission)
                else (:missing admission ?:)
                'Investor'
             else(:Investor created in SMED (button create investor):)
              'Investor'
        else 
          $enterprise/Settings/Teams
    else
      'Beneficiary'
};

(: ======================================================================
   TODO: a future version could return both 'Investor' and 'Corporate'
   instead of 'Investor / Corporate'
   ====================================================================== 
:)
declare function enterprise:organisationTypeFromAdmission( $admission as element()) as xs:string
{
if(exists($admission/CreateOrganisation[OrganisationInformation/InvestCorpoOrganisationsTypes])) then (:new admission with organisation type in investor:)
  if( exists($admission/CreateOrganisation[OrganisationInformation/InvestCorpoOrganisationsTypes[InvestCorpoOrganisationsTypeRef = '611']]) 
  or exists($admission/CreateOrganisation[OrganisationInformation/CorporateProfile/Type/CorporateTypes[CorporateTypeRef = '1']])
  ) then (:organisation type investor checked or corporate venture capital in corporate type:)
   if(exists($admission/CreateOrganisation[OrganisationInformation/CorporateProfile]) 
   and not(exists($admission/CreateOrganisation[OrganisationInformation/InvestorProfile/InvestorTypes[InvestorTypeRef !='4']]))
   and not(exists($admission/CreateOrganisation[OrganisationInformation/CorporateProfile/Type/CorporateTypes[CorporateTypeRef != '1']]))
   ) then
      'Corporate'
   else
     if(exists($admission/CreateOrganisation[OrganisationInformation/CorporateProfile]) or exists($admission/CreateOrganisation[OrganisationInformation/InvestorProfile/InvestorTypes[InvestorTypeRef !='4']])) then
        'Investor / Corporate'
     else
      'Investor'
  else (:organisation type corporate only checked:)
   'Corporate'
else (:old admission without organisation type in investor:)
  'Investor'

};

(: ======================================================================
   Check an organisation belongs to one of the provided CompanyTypes
   FIXME: refactor organisation coding to replace it with a single equality
   ====================================================================== 
:)
declare function enterprise:organisation-is-a ( $enterprise as element(), $type-refs as xs:string? ) as xs:boolean {
  some $t in $type-refs satisfies
    switch ($t)
      case '1' (: SME :)
        return empty($enterprise/ValidationStatus/CompanyTypeRef) or $enterprise/ValidationStatus/CompanyTypeRef eq '1'
      case '2' (: Not SME :)
        return $enterprise/ValidationStatus/CompanyTypeRef = '2'
      case '3' (: Investor - or actually treated as Investor :)
        return $enterprise/Settings/Teams = 'Investor'
      case '4' (: Corporate :)
        return
          if ($enterprise/@AdmissionKey) then
            let $admission := fn:collection($globals:admissions-uri)//Admission[Id eq $enterprise/@AdmissionKey]
            return $admission//InvestCorpoOrganisationsTypeRef eq '612'
          else
            false()
      default (: 5 - EEN :)
        return $enterprise/Settings/Teams = 'EEN'
};

(: ======================================================================
   Return boolean to tell if $enterprise can apply to some $event
   ====================================================================== 
:)
declare function enterprise:can-apply-to-event( $enterprise as element(), $event as element() ) as xs:boolean {
  let $org-type := enterprise:organisationType($enterprise/Id)
  return
    $org-type = 'Beneficiary' or 
    ($org-type = ('Investor', 'Investor / Corporate') and (exists($event/Processing[@Role='investor']))) or 
    ($enterprise/Settings/Events and $enterprise/Settings/Events eq 'all')
};

(: ======================================================================
   Check a person account has a given role in a given company, 
   or has a given role in absolute (if no company)
   Useful to test a team member is the MatchInvest token holder
   ====================================================================== 
:)
declare function enterprise:has-function( $ref as xs:string?, $eref as xs:string?, $fref as xs:string ) as xs:boolean {
  if ($ref) then
    if ($eref) then
      exists(fn:collection($globals:persons-uri)//Person[Id eq $ref]/UserProfile/Roles/Role[FunctionRef eq $fref][EnterpriseRef eq $eref])
    else
      exists(fn:collection($globals:persons-uri)//Person[Id eq $ref]/UserProfile/Roles/Role[FunctionRef eq $fref])
  else
    false()
};

(: ======================================================================
   Propagate company update to ScaleupEU service
   Return previous success message augmented with ScaleupEU feedback
   ====================================================================== 
:)
declare function enterprise:update-scaleup ( $enterprise as element(), $success as element()? ) {
  let $account := enterprise:get-token-owner-person-for($enterprise)
  return
    if (exists($account)) then
      let $member := $enterprise/Team/Members/Member[PersonRef eq $account/Id]
      let $last := enterprise:get-most-recent-request($enterprise, $account/Id)
      (: pre-condition: MUST be the 'allocated' TokenRequest :)
      return
        if (exists($member)) then
          let $payload := enterprise:gen-scaleup-update($enterprise, $member)
          return
            let $res := enterprise:get-match-invest-response(
                          services:post-to-service('invest', 'invest.end-point', $payload, "200"), ()
                          )
            return (
              if (local-name($res) ne 'error' and ($payload/Contact/Email ne $last/Email)) then
                template:do-update-resource('token', (), $last, (), <Form>{ $payload/Contact/Email }</Form>)
              else
                (),
              $res
              )
        else
          ajax:concat-message(oppidum:throw-error('CUSTOM', 'ScaleupEU synchronization cancelled because the current investor contact is not a known member'), $success/message)
    else
      $success
};

(: ======================================================================
   Propagate individual user account update to ScaleupEU service
   @op is update or suspend
   @category is the investor or monitor
   Update TokenRequest in user account token history to track Email changes
   NOTE: currently delete operation is only implemented in console
   Return error or success message
   ====================================================================== 
:)
declare function enterprise:update-scaleup-individual ( $account as element(), $op as xs:string, $category as xs:string) as element()? {
  enterprise:update-scaleup-individual ( $account, $op, $category, ())
};

declare function enterprise:update-scaleup-individual ( $account as element(), $op as xs:string, $category as xs:string, $data  as element()?) as element()? {
  let $form := <Form>
                <Operation>{ $op }</Operation>
                <Category>{ $category }</Category>
                { $data }
              </Form>
  let $payload := if (exists($data)) then 
      template:gen-document('scaleup-individual-wstoken-from-forms', 'update', $account, $account//TokenHistory[@For eq 'ScaleupEU']/TokenRequest, $form)
    else
      template:gen-document('scaleup-individual-wstoken', 'update', $account, $account//TokenHistory[@For eq 'ScaleupEU']/TokenRequest, $form)
  return
    if (local-name($payload) ne 'error') then
      let $last := $account//TokenHistory[@For eq 'ScaleupEU']/TokenRequest
      let $tpl-name := if ($op eq 'update') then 'token-allocate' else if ($op eq 'suspend') then 'token-withdraw' else ()
      let $res := enterprise:get-match-invest-response(
                    services:post-to-service('invest', 'invest.end-point', $payload, "200"), ()
                    )
      return (
        if (local-name($res) ne 'error') then
          if (exists($last)) then
            if (exists($tpl-name)) then (: sanity check :)
              template:do-update-resource($tpl-name, (), $last, (), <Form>{ $account/Information/Contacts/Email }</Form>)
            else
              ()
          else if ($op eq 'update') then
             template:do-create-resource('individual-token', $account, (), <Form>{ $account/Information/Contacts/Email }</Form>, ())
          else
            ()
        else
          (),
        $res
        )[last()]
    else
      $payload
};

(: ======================================================================
   Return update message payload for ScaleupEU application for $enterprise
   with token owner $member from the Team.
   Infer the LastEmail account key in case of account key transfer.
   ====================================================================== 
:)
declare function enterprise:gen-scaleup-update( $enterprise as element(), $member as element() ) as element() {
  <Company>
    <Operation>update</Operation>
    <Category>{ local:get-category($enterprise) }</Category>
    <CompanyId>{ $enterprise/Id/text() }</CompanyId>
    {
    $enterprise/Information/(Name | WebSite | Address/( StreetNameAndNo | PostalCode | Town | Nuts | custom:normalize-country((Country | ISO3CountryRef)[1]) ) | CreationYear | SizeRef | ServicesAndProductsOffered/DomainActivities/DomainActivityRef[1] | TargetedMarkets | TargetedContextRef)
    }
    <Contact>
      {
      $member/Information/(Sex | Name | Contacts/Email | CorporateFunctions | Function | Contacts/Phone | Contacts/Mobile | Contacts/Email),
      local:get-contact-eu-login($member) 
      }
    </Contact>
    {
    let $last := enterprise:get-token-owner-mail($enterprise)
    return 
      if (exists($last) and ($last ne $member/Information/Contacts/Email)) then (: account key tracking protocol :)
        <LastEmail>{ $last }</LastEmail>
      else
        ()
    }
  </Company>
};

(: ======================================================================
   Return suspend message payload for ScaleupEU application for $enterprise
   with token owner $member. Requires the Email account key to suspend 
   which must correspond to the one the $member was registered with.
   ====================================================================== 
:)
declare function enterprise:gen-scaleup-suspend( $enterprise as element(), $member as element(), $email-key as xs:string ) as element() {
  <Company>
    <Operation>suspend</Operation>
    <Category>{ local:get-category($enterprise) }</Category>
    <CompanyId>{ $enterprise/Id/text() }</CompanyId>
    <Contact>
      <Email>{ $email-key }</Email>
      { local:get-contact-eu-login($member) }
    </Contact>
  </Company>
};

(: ======================================================================
   Return a <success> or <error> informing about MatchInvest service invocation outcome
   DEPRECATED: error decoding is now done at services.xqm level and could be removed
   TODO: switching to EXPath http-client could make decoding easier
   ======================================================================
:)
declare function local:decode-match-invest-response( $res as element() ) as element()? {
  if (exists($res/*[local-name(.) eq 'body'])) then
    try { 
      let $decode := util:parse(xdb:decode-uri($res/*[local-name(.) eq 'body']))
      return
        if (exists($decode//Error)) then
          <error>Company profile not synchronized with ScaleupEU service (status { string($decode//Response/@status) } : { string($decode//Error) })</error>
        else
          <success>Company profile synchronized with ScaleupEU service (status { string($decode//Response/@status) })</success>
    } catch * { 
      <success>Company profile synchronization with ScaleupEU service may have fail, could not decode response</success>
    }
  else if (local-name($res) eq 'success' and ($res/@status)) then
    <success>Company profile not synchronized with ScaleupEU (service unplugged)</success>
  else (: FIXME: silent success ? :)
    <success>Company profile synchronization with ScaleupEU service may have fail, empty response</success>
};

(: ======================================================================
   Analyse MatchInvest $res service response and combine it with optional 
   previous success operation (e.g. database update)
   Throw error if any. Return Ajax success or error message.
   ====================================================================== 
:)
declare function enterprise:get-match-invest-response( $res as element(), $success as element()? ) as element() {
  if (local-name($res) ne 'error') then
    let $decode := local:decode-match-invest-response($res)
    return
      if (local-name($decode) eq 'success') then
        (: decode MatchInvest response to augment Ajax feedback :)
        if (exists($success)) then
          ajax:concat-message($success, $decode)
        else
          $decode
      else
        ajax:concat-message(oppidum:throw-error('CUSTOM', $decode), $success/message)
  else
    ajax:concat-message(oppidum:throw-error('CUSTOM', $res/message/text()), $success/message)
};

(: ======================================================================
   Return true() if the Scaleup token is allocated to the $mail address
   in a company other than $id. Return false() otherwise.
   FIXME: should take Email from last allocated/suspended token in TokenHistory ?
   ====================================================================== 
:)
declare function enterprise:some-other-has-token-for( $mail as xs:string, $id as xs:string ) as xs:boolean {
  let $key := lower-case($mail) (: sanitization :)
  return
    some $member in globals:collection('enterprises-uri')//Enterprise/Team//Member[descendant::Email eq $key]
    satisfies $member/ancestor::Enterprise/Id ne $id
              and lower-case($member/Information/Contacts/Email) eq $key
              and exists(globals:collection('persons-uri')/Person[descendant::Role[FunctionRef eq '8'][EnterpriseRef eq $member/ancestor::Enterprise/Id]])
};

(: ======================================================================
   Return the Person model of the company token owner
   Return the empty sequence if no one owns the token
   Note: alternative (slow) could uses 'mi-token' role in member account
   ====================================================================== 
:)
declare function enterprise:get-token-owner-person-for( $enterprise as element() ) as element()? {
  let $token := enterprise:get-last-scaleup-request($enterprise)
  return
    if ($token/TokenStatusRef eq '3') then
      globals:collection('persons-uri')//Person[Id eq $token/PersonKey]
    else
      ()
};

(: ======================================================================
   Return latest TokenRequest made by the given user
   ======================================================================
:)
declare function enterprise:get-most-recent-request ( $enterprise as element(), $person-key as xs:string? ) {
  if ($person-key) then
    head(
      for $req in $enterprise//TokenHistory[@For eq 'ScaleupEU']/TokenRequest[PersonKey eq $person-key]
      order by number($req/Order) descending
      return $req
    )
  else
    ()
};

(: ======================================================================
   Return latest TokenRequest sent to the ScaleupEU third-part application.
   Except delete request since it deletes the account !
   ====================================================================== 
:)
declare function enterprise:get-last-scaleup-request ( $enterprise as element() ) as element()? {
  head(
    for $req in $enterprise//TokenHistory[@For eq 'ScaleupEU']/TokenRequest[TokenStatusRef = ('3', '4')]
    order by number($req/Order) descending
    return $req
  )
};

(: ======================================================================
   Return Email address of the $enterprise token owner. This is the last
   Email address that was sent to the ScaleupEU third-part application.
   Return the empty sequence if no current token owner.
   ====================================================================== 
:)
declare function enterprise:get-token-owner-mail ( $enterprise as element() ) as xs:string? {
  let $last-token := enterprise:get-last-scaleup-request($enterprise)
  return
    if (exists($last-token)) then
      $last-token/Email
    else 
      ()
};

