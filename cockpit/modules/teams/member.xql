xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage a Member in an Enterprise from the Team acordion

   Creates a LEAR 

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:validate-mail-address-for( $mail as xs:string, $member as element()? ) as element()?
{
  if (exists($member) and ($mail ne lower-case($member/Information/Contacts/Email))) then
    if (exists($member/PersonRef)) then (: already accredited :)
      if (exists(globals:collection('persons-uri')//UserProfile[lower-case(Email[@Name eq 'ECAS']) eq $mail])) then
          (: someone else already accredited with same email 
             TODO: ideally we could merge both account :)
          oppidum:throw-error('EMAIL-TAKEN', ($mail))
      else
          (: no one else already accredited with same email 
             TODO: ideally we could only update member email in UserProfile/Email :)
          oppidum:throw-error('EMAIL-ALREADY-ACCREDITED', ($member/Information/Contacts/Email, $mail))
    else
      ()
  else
    ()
};

(: ======================================================================
   Validate submitted data
   Return first error to report or the empty sequence

   See https://webgate.ec.europa.eu/CITnet/confluence/display/SMEIMKT/SME+Dashboard+constraints
   ======================================================================
:)
declare function local:validate-submission( $submitted as element(), $enterprise as element(), $id as xs:string?, $member as element()? ) as element()? {
  let $mail := lower-case($submitted/Contacts/Email)
  return
    (: Member Email unicity :)
    if (some $member in $enterprise/Team/Members/Member 
          satisfies 
            lower-case($member/Information/Contacts/Email) eq $mail
            and (empty($id) or ($member/Id ne $id))) then
      oppidum:throw-error('CUSTOM', concat('This email (', $submitted//Email, ') is already taken by another team member'))
      
    (: ScaleupEU token unicity :)
    else if (enterprise:some-other-has-token-for($mail, $enterprise/Id)) then
      (: ideally there are some groups that never ask token for which we could avoid this test  :)
      oppidum:throw-error('TOKEN-TAKEN', ($mail, head(($enterprise/Information/ShortName, $enterprise/Information/ShortName))))
      
    else 
      local:validate-mail-address-for($mail, $member)
};

declare function local:get-person( $ref as xs:string? ) as element()? {
  if ($ref) then
    fn:collection($globals:persons-uri)//Person[Id eq $ref]
  else
    ()
};

(: ======================================================================
   Uses the submitted form data to create a new LEAR
   Uses the Ajax confirmation protocols if there is already a LEAR 
   and downgrades him to Delegate upon confirmation
   ======================================================================
:)
declare function local:replace-or-create-lear( $submitted as element(), $enterprise as element() ) {
  let $cie-ref := $enterprise/Id
  let $team-refs := $enterprise//Member/PersonRef
  let $cur-lear := globals:collection('persons-uri')/Person[Id = $team-refs][.//Role[FunctionRef eq '3' and EnterpriseRef eq $cie-ref]]
  return
    if ((request:get-parameter('_confirmed', ()) eq '1') or empty($cur-lear)) then
      let $mail-key := lower-case($submitted/Contacts/Email)
      let $realm-name := 'ECAS' (: FIXME: single hard-coded at the moment - oppidum:get-current-user-realm():)
      let $person := globals:collection('persons-uri')//Person[UserProfile/lower-case(Email[@Name eq $realm-name]) eq $mail-key]
      let $res := 
        (: NOTE: we use two different "lear" templates, we could as well use a single one 
           and push these tests inside it :)
        if (exists($person)) then (: LEAR already has an account :)
          template:do-update-resource('lear', $person/Id, $enterprise, $person, $submitted)
        else (: LEAR has no account yet :)
          template:do-create-resource('lear', $enterprise, (), $submitted, ())
      return
        if (local-name($res) ne 'error') then
          if (exists($cur-lear)) then (: updates previous LEAR roles in Enterprise :)
            let $action := <Roles>
                             <Remove><FunctionRef>3</FunctionRef></Remove>
                             <Add><FunctionRef>4</FunctionRef></Add>
                           </Roles>
            let $res := template:do-update-resource('roles', 
                          (),
                          fn:head($cur-lear),
                          $enterprise/Team//Member[PersonRef eq fn:head($cur-lear)/Id],
                          $action)
            return
              if (local-name($res) ne 'error') then
                ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), $cie-ref)
              else (: FIXME: we could just oppidum:add-error to report error in flash and return success :)
                $res
          else
            ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), $cie-ref)
        else
          $res
  else
    let $member := $enterprise/Team//Member[PersonRef eq head($cur-lear)/Id]
    let $name := concat($member/Information/Name/FirstName, ' ', $member/Information/Name/LastName)
    return
      oppidum:throw-message("REPLACE-LEAR-CONFIRM", (
        $name,
        concat($submitted/Name/FirstName, ' ', $submitted/Name/LastName),
        $name
        ))
};

(: ======================================================================
   Create a DG inside Directorate-General company
   ====================================================================== 
:)
declare function local:create-dg( $submitted as element(), $enterprise as element() ) {
  let $cie-ref := $enterprise/Id
  return
    let $mail-key := lower-case($submitted/Contacts/Email)
    let $realm-name := 'ECAS' (: FIXME: single hard-coded at the moment - oppidum:get-current-user-realm():)
    let $person := globals:collection('persons-uri')//Person[UserProfile/lower-case(Email[@Name eq $realm-name]) eq $mail-key]
    let $res := 
      (: NOTE: we use two different "dg" templates, we could as well use a single one 
         and push these tests inside it :)
      if (exists($person)) then (: DG already has an account :)
        () (:template:do-update-resource('DG', $person/Id, $enterprise, $person, $submitted):)
      else (: DG has no account yet :)
        template:do-create-resource('DG', $enterprise, (), $submitted, ())
    return
      if (local-name($res) ne 'error') then
        ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), $cie-ref)
      else (: FIXME: we could just oppidum:add-error to report error in flash and return success :)
        $res
};

(: ======================================================================
   Create an Investor inside an Investor company
   An Investor is directly accredited and can access the platform
   An Investor can be registered in several companies
   TODO: merge with create-DG
   ====================================================================== 
:)
declare function local:create-investor( $submitted as element(), $enterprise as element() ) {
  let $cie-ref := $enterprise/Id
  return
    let $mail-key := lower-case($submitted/Contacts/Email)
    let $realm-name := 'ECAS' (: FIXME: single hard-coded at the moment - oppidum:get-current-user-realm():)
    let $person := globals:collection('persons-uri')//Person[UserProfile/lower-case(Email[@Name eq $realm-name]) eq $mail-key]
    let $res := 
      (: NOTE: we use two different "dg" templates, we could as well use a single one 
         and push these tests inside it :)
      if (exists($person)) then (: Investor already has an account :)
        template:do-update-resource('investor-member', $person/Id, $enterprise, $person, $submitted)
      else (: Investor has no account yet :)
        template:do-create-resource('investor', $enterprise, <FunctionRef>7</FunctionRef>, $submitted, ())
    return
      if (local-name($res) ne 'error') then
        ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), $cie-ref)
      else (: FIXME: we could just oppidum:add-error to report error in flash and return success :)
        $res
};

(: ======================================================================
   Update a member record
   Synchronize with thir part services as needed
   TODO: ask confirmation if changing Email and propagate change to 
         - user account (should we remove Remote @Name="ECAS" ?)
         - TokenHistory if token owner
   ====================================================================== 
:)
declare function local:update-member(
  $id as xs:string, 
  $enterprise as element(), 
  $member as element(), 
  $submitted as element()
  ) as element()
{
  if (deep-equal($member/Information/*, $submitted/*)) then  (: form order congruent with DB order :)
    ajax:report-success('ACTION-UPDATE-NOCHANGE', ())
  else
    let $has-token := enterprise:has-function($member/PersonRef, $enterprise/Id, '8')
    let $has-edited-email := ($member/Information/Contacts/Email ne $submitted/Contacts/Email)
    return
      if ($has-token 
          and $has-edited-email
          and enterprise:some-other-has-token-for($submitted/Contacts/Email, $enterprise/Id))
      then
        oppidum:throw-error('TOKEN-TAKEN', (string($submitted/Contacts/Email), head($enterprise/Information/(Name | ShortName))))
      else
        let $person := () (: not used - local:get-person($member/PersonRef :)
        let $update := template:update-resource-id('team-member', $id, $enterprise, $person, $submitted)
        return
          if (local-name($update) eq 'success' and $has-token) then
            (: TODO: call only if significant delta :)
            enterprise:update-scaleup($enterprise, $update)
          else
            $update
};

(: ======================================================================
   Create an unaffiliated user
   Check correct HTTP verb and access right
   ====================================================================== 
:)
declare function local:create-unaffiliated( $m as xs:string, $type as xs:string?, $submitted as element()? ) {
  if ($m eq 'POST'and access:check-entity-permissions('add', 'Unaffiliated')) then
    let $mail-key := lower-case($submitted/Contacts/Email)
    let $realm-name := 'ECAS'
    let $person := globals:collection('persons-uri')//Person[UserProfile/lower-case(Email[@Name eq $realm-name]) eq $mail-key]
    return
      if (exists($person)) then
        oppidum:throw-error('ACCOUNT-DUPLICATED-LOGIN', $mail-key)
      else
        let $res := template:do-create-resource('unaffiliated-user', (), (), $submitted, ())
        return
          if (local-name($res) ne 'error') then
            oppidum:throw-message('CREATE-UNAFFILIATED-SUCCESS', $res/@key)
          else
            $res
  else
    oppidum:throw-error('URI-NOT-SUPPORTED', ())
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $steps := tokenize($cmd/@trail, '/')
let $enterprise-no := $steps[2]
return
  if ($enterprise-no eq 'unaffiliated') then
    local:create-unaffiliated($m, $steps[3], oppidum:get-data())
  else
    let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $enterprise-no]
    let $goal := if ($m = 'POST') then 'update' else 'view'
    let $id := $steps[4]
    let $member := if ($id) then $enterprise/Team/Members/Member[Id eq $id] else ()
    let $access := access:get-tab-permissions($goal, 'team-member', $enterprise, $member)
    return
      if (local-name($access) eq 'allow') then
        if ($m = 'POST') then
          let $submitted := oppidum:get-data()
          let $error := local:validate-submission($submitted, $enterprise, $id, $member)
          return
            if (exists($error)) then
              $error
            else if ($cmd/resource/@name = ('members')) then (: Creates a delegate member :)
              let $res := template:do-create-resource('team-member', $enterprise, (), $submitted, ())
              return
                if (local-name($res) ne 'error') then
                   ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), $enterprise-no)
                else
                  $res
            else if ($cmd/resource/@name eq 'DG') then (: Creates a DG member :)
              local:create-dg($submitted, $enterprise)
            else if ($cmd/resource/@name eq 'investor') then (: Creates an investor member :)
              local:create-investor($submitted, $enterprise)
            else if ($cmd/resource/@name eq 'LEAR') then (: Creates a LEAR member :)
              local:replace-or-create-lear($submitted, $enterprise)
            else if ($id) then (: Updates an existing team member :)
              local:update-member($id, $enterprise, $member, $submitted)
            else
              oppidum:throw-error('URI-NOT-FOUND', ())
        else (: assumes GET :)
          let $person := () (:local:get-person($member/PersonRef - not used :)
          return
            template:gen-read-model-id('team-member', $id, $enterprise, $person, 'en')
      else
        $access
