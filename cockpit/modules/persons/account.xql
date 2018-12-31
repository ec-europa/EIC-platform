xquery version "1.0";
(: --------------------------------------
   SMEIMKT SME Dashboard application

   Authors: 
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   CRUD controller to manage user accounts
   (user account information is stored in Person element in /persons collection)

   TODO:
   - as a side effect of updating External Login Email (EU Login Email)
     we should consider to update Master information Email 
     and all team Member email connected to this user account ?

   Since December 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../modules/enterprises/enterprise.xqm";
import module namespace drupal = "http://oppidoc.com/ns/application/drupal" at "../community/drupal.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Normalize e-mail string for comparison
   ======================================================================
:)
declare function local:normalize( $str as xs:string? ) as xs:string {
  upper-case(normalize-space($str))
};

(: ======================================================================
   Check that updating ECAS Email would not break any previously 
   allocated ScaleupEU token on that Email
   ====================================================================== 
:)
declare function local:assert-scaleup-email( $data as element(), $account as element()? ) as element()? {
  let $mail-key := local:normalize($data/External/Email)
  let $prev-email := local:normalize($account/UserProfile/Email[@Name eq 'ECAS'])
  return
    if ($mail-key ne $prev-email) then
      (: assume 1 token max per user account :)
      let $cie-ref := $account/UserProfile//Role[FunctionRef eq '8']/EnterpriseRef
      return
        if ($cie-ref) then
          let $enterprise := globals:collection('enterprises-uri')//Enterprise[Id eq $cie-ref]
          return
             if ($enterprise and local:normalize(enterprise:get-token-owner-mail($enterprise)) eq $prev-email) then
               ajax:throw-error('TOKEN-ALLOCATED', 
                 (display:gen-person-name-for-account($account/Id), $enterprise/Information/Name, $account/UserProfile/Email[@Name eq 'ECAS'])
               )
             else
               ()
        else
         ()
     else
       ()
};

(: ======================================================================
   Check that there is enough master information recorded if the user
   has a ScaleupEU consultant role (investor or facilitator)
   FIXME: hard-coded roles in predicate
   ====================================================================== 
:)
declare function local:assert-scaleup-individual( $data as element(), $account as element()? ) as element()? {
  if ($account/UserProfile//Role[FunctionRef = ('10', '11')]) then
    if (empty($data/Member/Name/FirstName) and empty($data/Member/Name/LastName) and empty($data/Member/Contacts/Email)) then 
      oppidum:throw-error('SCALEUPEU-MASTER-MANDATORY', ())
    else
      ()
  else
    ()
};

(: ======================================================================
   Checks submitted user account information
   Validate for creation if curNo is empty or for updating otherwise
   Return a list of error messages or the emtpy sequence if no errors

   See https://webgate.ec.europa.eu/CITnet/confluence/display/SMEIMKT/SME+Dashboard+constraints
   ======================================================================
:)
declare function local:validate-person-submission( $data as element(), $account as element()?, $curNo as xs:string? ) as element()* {
  (: Submission with remote login must be complete (realm and key) :)
  let $mail:= $data/External/Email[. ne '']
  let $rem := $data/External/Remote[. ne '']
  let $realm := $data/External/Realm[. ne '']
  return
    if (empty($realm) or (empty($mail) and empty($rem))) then
      oppidum:throw-error('CUSTOM', 'The realm has not been setup')
    else
      (: ECAS Email unicity :)
      let $email-key := local:normalize($mail)
      let $local-mail := globals:collection('persons-uri')//Person[local:normalize(UserProfile/Email) eq $email-key]
      return
        if (exists($local-mail) and ((empty($curNo)) or not($curNo = $local-mail/Id))) then
          ajax:throw-error('DUPLICATED-EMAIL', ($mail, display:gen-person-name-for-account($local-mail/Id[1])))
        else 
          (: ECAS login unicity :)
          let $remote-key := if (exists($rem)) then local:normalize($rem) else ()
          let $local-login := globals:collection('persons-uri')//Person[local:normalize((UserProfile/Remote[string(@Name) eq 'ECAS'],'')[1]) eq $remote-key]
          return
            if (exists($local-login) and ((empty($curNo)) or not($curNo = $local-login/Id))) then 
              ajax:throw-error('CUSTOM', 
                concat('Duplicated', 
                  let $duplicate := if (empty($curNo)) then $local-login[1] else $local-login[Id ne $curNo][1]
                  return
                    $duplicate/UserProfile/Remote[string(@Name) eq 'ECAS']
                )
              )
            else

              (: ScaleupEU token unicity - see also teams/member.xql :)
              (: actually we do not need to test it since there are good chances that ECAS Email unicity
                 prevents stealing a token Email address - eventually we could imagine a user ECAS Email
                 has been edited in a Team member record to give another address to get a token for 
                 but the risk seem so low we do not test for it...  :)

              (: ScaleupEU token e-mail update :)
              (: not implemented, suggest to withdraw token first ! :)
              let $scaleup-update := local:assert-scaleup-email($data, $account)
              return
                if (exists($scaleup-update)) then
                  $scaleup-update
                else

                  (: User master information preservation :)
                  if (count($data/Member//*[. ne '']) eq 0 and count(globals:collection('enterprises-uri')//Enterprise/Team//Member[PersonRef eq $curNo]) eq 0) then
                    ajax:throw-error('CUSTOM', "You cannot remove master personal information from an unaffiliated user")
                  else
                    local:assert-scaleup-individual($data, $account)
};

(: ======================================================================
   Regenerates the UserProfile for the current submitted person whether s/he exists or not
   Interprets current request "f" parameter to assign "kam" or "coach" function on the fly
   FIXME: 
   - access control layer before promoting a kam or coach ?
   - ServiceRef and / or RegionalEntityRef should be upgraded on workflow transitions
   ======================================================================
:)
declare function local:gen-user-profile-for-writing( $profile as element()?, $external as element()? ) {
  let $remote := 
    if (exists($external/Realm[. ne '']) and exists($external/Remote[. ne ''])) then
      <Remote Name="{ $external/Realm/text() }">{ $external/Remote/text() }</Remote>
    else
      ()
  let $mail :=
    if (exists($external/Realm[. ne '']) and exists($external/Email[. ne ''])) then
      <Email Name="{ $external/Realm/text() }">{ $external/Email/text() }</Email>
    else
      ()
  return
    if (access:check-omnipotent-user()) then
      <UserProfile>
        {
        $mail,
        $profile/*[not(local-name(.) = ('Remote','Email'))],
        $remote
        }
      </UserProfile>
    else
      $profile (: a user editing his person record cannot change his profile :)
};

(: ======================================================================
   Reconstructs a Person record from current Person data and from new submitted
   Person data. Note that current Person may be the empty sequence in case of creation.
   Persists UserProfile and Information element if present.
   FIXME: to be used for implementing [Add Account] command in user management 
   ======================================================================
:)
declare function local:gen-person-for-writing( $current as element()?, $submitted as element(), $index as xs:integer? ) {
  let $info := template:gen-document('person-information', 'create', $submitted/Member)
  return
    <Person>
      {
      if (local-name($info) eq 'error') then (: trick to return error message :)
        attribute { 'error' } { string($info/message) }
      else
        (),
      if ($current) then
        $current/Id 
      else 
        <Id>{$index}</Id>,
      local:gen-user-profile-for-writing($current/UserProfile, $submitted/External),
      if (local-name($info) ne 'error') then
        $info
      else
        $current/Information
      }
    </Person>
};

(: ======================================================================
   Updates a Person model into database
   Returns Person model including the update flag (since the user must be allowed)
   ======================================================================
:)
declare function local:update-person( $current as element(), $data as element(), $format as xs:string ) as element() {
  let $person := local:gen-person-for-writing($current, $data,())
  let $update-scaleup := $current/UserProfile//Role[FunctionRef = ('10', '11')] and
                         ($person/Information/Name/FirstName ne $current/Information/Name/FirstName or 
                          $person/Information/Name/LastName ne $current/Information/Name/LastName or
                          $person/Information/Contacts/Email ne $current/Information/Contacts/Email)
  let $info := template:gen-document('person-information', 'create', $data/Member)
  let $user-profile := local:gen-user-profile-for-writing($current/UserProfile, $data/External)
  return (
    if (local-name($info) ne 'error') then 
      misc:save-content($current, $current/Information, $info)
    else (: misc:save-content is non destructive :)
      update delete $current/Information,
    misc:save-content($current, $current/UserProfile, $user-profile),
    (: Ajax XML table protocol or Ajax HTML table protocol :)
    let $result := ajax:report-success('ACTION-UPDATE-SUCCESS', (), 
                     <Payload Key="person">{ $person/(Id | UserProfile/Remote | UserProfile/Email) }</Payload>)
    return
      if (local-name($info) eq 'error') then (
        response:set-status-code(200),  (: reset status to avoid beeing treated as error :)
        ajax:concat-message($result, $info/message)
        )
      else if ($update-scaleup) then
        ajax:concat-message($result,
          enterprise:update-scaleup-individual($current, 'update',
            if ($person/UserProfile//Role/FunctionRef = '10') then 'facilitator' else 'monitor')
          )
      else
        $result
    )[last()]
};

(: ======================================================================
   Utility to generate remote login information (Key, Realm) for person
   ====================================================================== 
:)
declare function local:gen-remote( $person ) as element()? {
  <External>
    { $person/UserProfile/(Email | Remote ) }
    <Realm>{ if ($person/UserProfile/Remote) then string($person/UserProfile/Remote/@Name) else string($person/UserProfile/Email/@Name)}</Realm>
  </External>
};

(: ======================================================================
   Returns a Person model for a given goal
   Note EnterpriseRef -> EnterpriseName for modal window
   TODO: use a data template
   ======================================================================
:)
declare function local:gen-person( $person as element(), $lang as xs:string, $goal as xs:string ) as element()* {
  if ($goal = 'update') then
    <Person>
      {
      local:gen-remote($person),
      if ($person/Information) then
        <Member>{ $person/Information/* }</Member>
      else
        ()
      }
    </Person>
  else
    ()
};

declare function local:POST-update-person( $cmd as element(), $ref as xs:string, $format as xs:string ) {
  let $person := if ($ref) then globals:collection('persons-uri')//Person[Id = $ref] else ()
  return
    if ($person) then
      if (access:check-omnipotent-user()) then
        let $data := oppidum:get-data()
        let $errors := local:validate-person-submission($data, $person, $ref)
        return
          if (empty($errors)) then
            local:update-person($person, $data, $format)
          else
            ajax:report-validation-errors($errors)
      else
        oppidum:throw-error('FORBIDDEN', ())
    else
      oppidum:throw-error("PERSON-NOT-FOUND", ())
};

declare function local:GET-person( $cmd as element(), $ref as xs:string ) {
  let $lang := string($cmd/@lang)
  let $person := if ($ref) then globals:collection('persons-uri')//Person[Id = $ref] else ()
  return
    if ($person) then
      (: access control done at mapping level :)
      local:gen-person($person, $lang, request:get-parameter('goal', 'read'))
    else
      oppidum:throw-error("PERSON-NOT-FOUND", ())
};

(: MAIN ENTRY POINT - CONTROLLER ROUTING :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $target := string($cmd/resource/@name)
let $format := request:get-parameter('format', 'xml')
return
  if ($m eq 'POST') then
    local:POST-update-person($cmd, $target, $format)
  else (: assumes GET profiles/{id} :)
    local:GET-person($cmd, $target)
