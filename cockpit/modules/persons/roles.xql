xquery version "3.0";
(: ------------------------------------------------------------------
   SMEIMKT SME Dashboad application

   Authors: 
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>
   - Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage roles in user accounts

   July 2018 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../../xcm/lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../xcm/lib/user.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../xcm/lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../modules/enterprises/enterprise.xqm";
import module namespace drupal = "http://oppidoc.com/ns/application/drupal" at "../community/drupal.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:log-event($task-msg as element()) {
    let $debug := globals:doc('settings-uri')/Settings/Module[Name eq "tasks"]/Property[Key/text() eq "debug"]
    return
    if (exists($debug)) then 
      let $level := $debug/Value/text()
      let $log-collection := $debug/Collection/text()
      let $log := $debug/Filename/text()
      let $log-uri := concat($log-collection, "/", $log)
      return
          (
          (: create the log file if it does not exist :)
          if (not(doc-available($log-uri))) then
              xmldb:store($log-collection, $log, <Tasks/>)
          else ()
          ,
          (: log messages to the log file :)         
          update insert $task-msg into doc($log-uri)/Tasks
          )
    else ()
};

(: ======================================================================
   For generation payload: Test if the user is a facilitator
   ====================================================================== 
:)
declare function local:is-a-facilitator($data as element()) as xs:boolean {
  if ( (exists($data/BusinessSegmentation[FacilitatorMonitorSelector eq '1'])) and (exists($data//BusinessSegmentationFacilitator//Location)) and 
       ( (exists($data/BusinessSegmentation[FacilitatorMonitorSelector eq '1']/BusinessSegmentationFacilitator/TargetGroupsFacilitator/TargetGroupFacilitatorCompanies[TargetGroupFacilitatorCompaniesSelector eq 'on'])) or 
         (exists($data/BusinessSegmentation[FacilitatorMonitorSelector eq '1']/BusinessSegmentationFacilitator/TargetGroupsFacilitator/TargetGroupFacilitatorInvestors[TargetGroupFacilitatorInvestorsSelector eq 'on'])) ) )  
  then
    true()
  else 
    false()
};


(: ======================================================================
   For generation payload: Test if the user is a facilitator
   ====================================================================== 
:)
declare function local:is-a-monitor($data as element()) as xs:boolean {
  if ( (exists($data/BusinessSegmentation[FacilitatorMonitorSelector eq '2'])) and (exists($data//BusinessSegmentationMonitor//Location)) and 
       ( (exists($data/BusinessSegmentation[FacilitatorMonitorSelector eq '2']/BusinessSegmentationMonitor/TargetGroupsMonitor/TargetGroupMonitorCompanies[TargetGroupMonitorCompaniesSelector eq 'on'])) or 
         (exists($data/BusinessSegmentation[FacilitatorMonitorSelector eq '2']/BusinessSegmentationMonitor/TargetGroupsMonitor/TargetGroupMonitorInvestors[TargetGroupMonitorInvestorsSelector eq 'on'])) ) )  
  then
    true()
  else 
    false()
};

(: ======================================================================
   Generate Payload to send back to client for dynamical update of user's
   result table row by management.js
   Be aware $data is in submitted data model with Enterprises place holder
   FIXME: Payload in payload 
   ====================================================================== 
:)
declare function local:gen-ajax-payload( $model as element(), $data as element() ) as element() {
  <Payload Key="profile">
    { $model/Id }
    <Roles>
      {
      if ( (($data/GenericRoles/Roles/Role or $data/Tokens/Static/Role) and ($data/GenericRoles[GenericRolesSelector eq 'on'])) or local:is-a-monitor($data) or local:is-a-facilitator($data)) then (
        if ($data/GenericRoles[GenericRolesSelector eq 'on']) then
        (
          for $role in $data/GenericRoles/Roles/Role 
          return <Role>{ display:gen-roles-for(<Roles>{$role}</Roles>, 'en') }</Role>,
          for $role in $data/Tokens/Static/Role
          return <Role>{ $role/Function/text() }</Role>
        )
        else
          ()
        ,
        if (local:is-a-facilitator($data)) then
          <Role>{ display:gen-roles-for(<Roles><Role><FunctionRef>10</FunctionRef></Role></Roles>, 'en') }</Role> 
        else (),
        if (local:is-a-monitor($data)) then
          <Role>{ display:gen-roles-for(<Roles><Role><FunctionRef>11</FunctionRef></Role></Roles>, 'en') }</Role> 
        else ()
        )
      else
        <Role>-</Role>
      }
    </Roles>
    <Personalities>
      {
        if ($data/GenericRoles[GenericRolesSelector eq 'on']) then
          (
          (: 1. affiliated roles => decode Information from Member record :)
          for $role in $data/GenericRoles/Roles/Role[Enterprises/EnterpriseRef]
          let $key := $role/Enterprises/EnterpriseRef
          let $ent := globals:collection('enterprises-uri')//Enterprise[Id eq $key]
          let $m := $ent/Team//Member[PersonRef eq $model/Id]
          group by $key
          return
            (<Pers Enterprise="{ $ent/Information/ShortName }">
              { 
              if ($m/Information/Name) then 
                $m/Information/Name
              else
                <Name>
                  <LastName>?</LastName>
                </Name>,
              $m/Information/Contacts/Email
              }
            </Pers>
            ,
            <AsMember><Company Id="{ $ent/Id/text() }">{ $ent/Information/ShortName }</Company></AsMember>
            ),
          (: 2. pending investor with AdmissionKey - should be unique :)
          (: FIXME: generate a fake <Pers> since static roles are pre-generated as string :)
          if (exists($data/Tokens/Static/Role)) then
            <Pers Enterprise="...">
              <Name>
                <FirstName></FirstName>
                <LastName>reload to get more personalities</LastName>
              </Name>
            </Pers>
          else
            ()
          )
        else
          ()
        ,
        (: 3. flatten unaffiliated roles => decode Information from Information in Person account :)
        if ($model/Information) then
          <Pers Enterprise="UNAFFILIATED">
            {
            $model/Information/Name,
            $model/Information/Contacts/Email
            }
          </Pers>
        else
          ()
      }
    </Personalities>
  </Payload>
};

(: ======================================================================
   Normalizes a string to compare it with another one
   TODO: handle accentuated characters (canonical form ?)
   ======================================================================
:)
declare function local:normalize( $str as xs:string? ) as xs:string {
  upper-case(normalize-space($str))
};

(: ======================================================================
   Check a given role with an EntepriseRef points with a compatible 
   enterprise using the @Team attribute of the "Functions" selector
   Pre-condition: $role with EnterpriseRef
   ====================================================================== 
:)
declare function local:assert-team-mismatch( $role as element()* ) {
  if ($role) then
    let $cur := fn:head($role)
    let $target := (globals:collection('global-info-uri')//Description[@Role = 'normative']/Selector[@Name eq 'Functions']//Option[Value eq $cur/FunctionRef]/@Team, 'Beneficiary')[1]
    return
      if (((globals:collection('enterprises-uri')//Enterprise[Id eq $cur/Enterprises/EnterpriseRef]/Settings/Teams, 'Beneficiary')[1] eq $target) or
          ((globals:collection('enterprises-uri')//Enterprise[Id eq $cur/Enterprises/EnterpriseRef]/Settings/Teams, 'Beneficiary')[1] eq 'EC')) then
        local:assert-team-mismatch(fn:tail($role))
      else
        ajax:throw-error('TEAM-MISMATCH', ($target, $target))
  else
    ()
};

(: ======================================================================
   Throw error if submitted $data define LEAR roles for companies 
   that already have a LEAR different than the user $account
   Throw one error per company in case multiple target company
   Hard-coded LEAR role '3'
   ====================================================================== 
:)
declare function local:assert-lear-unicity( $data as item()?, $account as element() ) as element()* {
  if ($data/GenericRoles[GenericRolesSelector eq 'on']) then
    for $cie-ref in distinct-values($data/GenericRoles/Roles/Role[FunctionRef eq '3']//EnterpriseRef)
    let $lear-ref :=  globals:collection('persons-uri')//Person[UserProfile//Role[FunctionRef eq '3' and EnterpriseRef eq $cie-ref]]/Id
    return
      if ($lear-ref ne $account/Id) then
        ajax:throw-error('ADD-LEAR-FORBIDDEN', 
          (display:gen-person-name-for-account($lear-ref), custom:gen-enterprise-name($cie-ref, 'en'))
          )
      else
        ()
  else 
    ()
};

(: ======================================================================
   Check the user does not already have a token
   Check that there is enough master information if the user is given
   a ScaleupEU consultant role (investor or facilitator)
   Finally if adding or remove a consultant role, actually 
   call the web service to do this and return an error in case of error
   FIXME: hard-coded roles in predicates
   ====================================================================== 
:)
declare function local:assert-scaleup-individual( $data as item()?, $account as element()? ) as element()? {
    if (local:is-a-facilitator($data) and local:is-a-monitor($data)) then
      oppidum:throw-error('SCALEUPEU-ONE-CONSULTANT', ())
    else if (($account/UserProfile//Role/FunctionRef = '8') and (local:is-a-facilitator($data) or local:is-a-monitor($data))) then
      oppidum:throw-error('SCALEUPEU-ONE-TOKEN', ())
    else if (($data/GenericRoles[GenericRolesSelector eq 'on']/Roles/Role[FunctionRef = ('7', '3', '4')]) and (local:is-a-facilitator($data) or local:is-a-monitor($data))) then
      oppidum:throw-error('SCALEUPEU-ONE-ROLE', ())
    else if (local:is-a-facilitator($data) or local:is-a-monitor($data)) then
      if (empty($account/Information/Name/FirstName) and empty($account/Information/Name/LastName) and empty($account/Information/Contacts/Email)) then 
        oppidum:throw-error('SCALEUPEU-MASTER-ERROR', ())
      else if (local:is-a-facilitator($data)) then
        (: new Facilitator role OR switch from Monitor to Factiliator or changing things in role => update :)
        enterprise:update-scaleup-individual($account, 'update', 'facilitator', $data)
      else if (local:is-a-monitor($data)) then
        (: new Monitor role OR switch from Factiliator to Monitor or changing things in role => update :)
        enterprise:update-scaleup-individual($account, 'update', 'monitor', $data)
      else
        ()
    else if ($account/UserProfile//Role/FunctionRef = ('10', '11')) then
      (: Facilitator or Monitor role has been removed => suspend :)
      if ($account/UserProfile//Role/FunctionRef = '10') then
        enterprise:update-scaleup-individual($account, 'suspend', 'facilitator', $data)
      else if ($account/UserProfile//Role/FunctionRef = '11') then
        enterprise:update-scaleup-individual($account, 'suspend', 'monitor', $data)
      else ()
    else
      ()
};


(: ======================================================================
  For each Location structure, Regions must be linked to Countries
  The Control is simple:
  - RegionID must contains Country ID - sample CH01 contains CH (two digits code for switzerland)
  - Countries can be empty ($allCountries test)
   ======================================================================
 :)
declare function local:validate-regions($data as item()?) as xs:boolean {
  let $regions := $data//RegionRef
  let $controls :=
    for $r in $regions
      let $allCountries := $r/../../Countries/CountryRef
      let $countries := $r/../../Countries/CountryRef[contains($r/text(), custom:get-country-code-value(text(), 'iso2'))]
      return
        (:if ((count($countries) > 0) or (count($allCountries) = 0)) then:)
        if (count($countries) > 0) then
          1
        else
          0
  return
    if ($controls = 0) then false() else true()
};

(: ======================================================================
  This kind of structures must not be empty at least one of the following elements:
  - CountryRef
  - RegionRef
  - EnterpriseRef
  - DomainActivityRef
  - TargetedMarketRef
   ======================================================================
 :)
declare function local:validate-all-locations($data as item()?) as xs:boolean {
  let $locations := $data//Locations
  return
    if ($locations//Location[not(descendant::CountryRef) and not(descendant::RegionRef) and not(descendant::EnterpriseRef) and not(descendant::DomainActivityRef) and not(descendant::TargetedMarketRef) and
                            ((../../TargetGroupFacilitatorCompaniesSelector[text() eq 'on']) or (../../TargetGroupFacilitatorInvestorsSelector[text() eq 'on'])
                             or (../../TargetGroupMonitorCompaniesSelector[text() eq 'on']) or (../../TargetGroupMonitorInvestorsSelector[text() eq 'on']))][../Location[(descendant::CountryRef) or (descendant::RegionRef) or (descendant::EnterpriseRef)  or (descendant::DomainActivityRef) or (descendant::TargetedMarketRef)]] ) then
      false()
    else 
      true()
};

(: ======================================================================
   Checks submitted data is correct
   Return an error or the empty sequence or <success> ScaleupEU message 
   to give feedback in case of  successful Facilitator or Monitor update 

   Be aware of $data data model with EntepriseRef within Enterprises !

   See https://webgate.ec.europa.eu/CITnet/confluence/display/SMEIMKT/SME+Dashboard+constraints
   ======================================================================
:)
declare function local:validate-profile-submission( $data as item()?, $account as element() ) as element()* {
  (: TODO Change validation process
    If monitor or facilitator or both are selected the Role can be empty ( User roles (editable here) section)
  :)
(:  let $logs := local:log-event($data):)
  let $ent-scope := custom:get-roles-in-scope('enterprise')
  let $val := local:validate-all-locations($data)
  let $var := local:validate-regions($data)
  return
    if (not($data instance of element())) then
      ajax:throw-error('VALIDATION-FORMAT-ERROR', ())
    else if (local-name($data) ne 'UserProfile') then
      ajax:throw-error('VALIDATION-ROOT-ERROR', local-name($data))
    else if (($data/GenericRoles/Roles/Role[not(FunctionRef)] or $data/GenericRoles/Roles/Role/FunctionRef[. eq '']) and ($data/GenericRoles[GenericRolesSelector eq 'on'])) then
      ajax:throw-error('VALIDATION-PROFILE-FAILED', local-name($data))
    else if ((count(distinct-values($data/GenericRoles/Roles/Role/FunctionRef[not(. = ('3', '4', '7'))])) ne count($data/GenericRoles/Roles/Role/FunctionRef[not(. = ('3', '4', '7'))])) and ($data/GenericRoles[GenericRolesSelector eq 'on'])) then
      ajax:throw-error('VALIDATION-DUPLICATED-ROLE', ())
    else if (($data/GenericRoles[GenericRolesSelector eq 'on']) and (some $x in distinct-values($data/GenericRoles/Roles/Role/FunctionRef[. = ('3', '4', '7')]) satisfies count($data/GenericRoles/Roles/Role[FunctionRef eq $x]/Enterprises/EnterpriseRef) ne count(distinct-values($data/GenericRoles/Roles/Role[FunctionRef eq $x]/Enterprises/EnterpriseRef)))) then
      ajax:throw-error('VALIDATION-DUPLICATED-ROLE', ())
    else if (($data/GenericRoles[GenericRolesSelector eq 'on']) and ($data/GenericRoles/Roles/Role/FunctionRef[. = $ent-scope][empty(..//EnterpriseRef)])) then
      ajax:throw-error('CUSTOM', 'Missing enterprise ref for LEAR/Delegate/DG/Investor role')
    else if (($data/GenericRoles[GenericRolesSelector eq 'on']) and ($data/GenericRoles/Roles/Role/FunctionRef[. = custom:get-roles-in-scope('program')][empty(..//ProgramId)])) then
      ajax:throw-error('CUSTOM', 'Missing program for the events manager role')
    else if (($data/GenericRoles[GenericRolesSelector eq 'on']) and (($account/UserProfile//Role/FunctionRef = '1' and not($data/GenericRoles/Roles/Role/FunctionRef = '1'))
             and user:get-current-person-id() eq $account/Id)) then
      ajax:throw-error('PROTECT-ADMIN-SYSTEM-ROLE', ())
    else if (($data/GenericRoles[GenericRolesSelector eq 'on']) and ($account/UserProfile/Roles/Role/FunctionRef = '8'
             and not($data/GenericRoles/Roles/Role//EnterpriseRef = $account/UserProfile/Roles/Role[FunctionRef eq '8']/EnterpriseRef))) then
      ajax:throw-error('TOKEN-ROLE-NEEDED', 
        (display:gen-person-name-for-account($account/Id), 
         custom:gen-enterprise-name($account/UserProfile/Roles/Role[FunctionRef eq '8']/EnterpriseRef[1], 'en'))
      )
    else if (not($data/GenericRoles[GenericRolesSelector eq 'on']) and ($account/UserProfile/Roles/Role[FunctionRef eq '8'])) then
      ajax:throw-error('CUSTOM', 
        concat("ScaleupEU Access cannot be removed that way - ",display:gen-person-name-for-account($account/Id), 
         custom:gen-enterprise-name($account/UserProfile/Roles/Role[FunctionRef eq '8']/EnterpriseRef[1], 'en'))
      )
    else if (not($val)) then
      ajax:throw-error('VALIDATION-LOCATION',())
    else if (not($var)) then
      ajax:throw-error('VALIDATION-REGION',())
    else
      let $lear-unicity := local:assert-lear-unicity($data, $account)
      return
        if ($lear-unicity) then
          $lear-unicity
        else
          let $team-mismatch := local:assert-team-mismatch($data/GenericRoles/Roles/Role[Enterprises/EnterpriseRef])
          return
            if ($team-mismatch) then 
              $team-mismatch
            else
              local:assert-scaleup-individual($data, $account)
};

(: ======================================================================
   Create a form including personal data from a previous Member if any
   or from unaffiliated Information block if any
   Use previous Member in first $still-refs when available
   See also: formulars/team-member.xml
   ======================================================================
:)
declare function local:fake-member-form( $account as element(), $still-refs as element()* ) as element() {
  let $id := $account/Id
  return
    <Form>
      <PersonRef>{ $id/text() }</PersonRef>
      {
      let $source :=
        if ($still-refs) then
          globals:collection('enterprises-uri')//Enterprise[Id eq $still-refs[1]]/Team/Members/Member[PersonRef eq $id]
        else
          let $fallback := fn:head(
                             globals:collection('enterprises-uri')//Enterprise/Team/Members/Member[PersonRef eq $id]
                           )
          return
            if ($fallback) then
              $fallback
            else (: final fallback on unaffiliated user :)
              $account
      return (
          $source/Information/( Sex | Civility | Name),
          <Contacts>
            {
            $source/Information/Contacts/( Phone | Mobile ),
            if ($source/Information/Contacts/Email[. ne '']) then
              $source/Information/Contacts/Email
            else if ($account//Email[@Name eq 'ECAS']) then
              <Email>{ $account//Email[@Name eq 'ECAS']/text() }</Email>
            else
              ()
            }
          </Contacts>,
          $source/Information/( CorporateFunctions | Function)
          )
      }
    </Form>
};

(: ======================================================================
   Post actions triggered on updating SME's attached to enterprise 
   scoped roles (not: excluding pending investor which MUST be static)
   Add or remove Member from corresponding enterprises
   ======================================================================
:)
declare function local:create-delete-members( $account as element(), $actual as element(), $former as element() ) {

  let $id := $account/Id
  let $inscope := custom:get-roles-in-scope('enterprise')
  let $actuals := $actual//Role[FunctionRef = $inscope]
  let $formers := $former//Role[FunctionRef = $inscope]
  return
    let $removed-ref := $formers/EnterpriseRef[not(. = $actuals/EnterpriseRef)]
    let $added-ref := $actuals/EnterpriseRef[not(. = $formers/EnterpriseRef)]
    let $still-ref := ($actuals/EnterpriseRef[not(. = ($removed-ref, $added-ref))])
    return
      <Feedback>
      {
      (: 1. add Member to Team in every new Enterprise :)
      let $form :=  local:fake-member-form( $account, $still-ref )
      return
        for $ref in $added-ref
        let $enterprise := globals:collection('enterprises-uri')//Enterprise[Id eq $ref]
        return
          if (empty($enterprise/Team/Members/Member[PersonRef eq $id])) then
            <Added
              complete="{if (string($form/Name/LastName) ne '') then '1' else '0' }"
              short="{ $enterprise/Information/ShortName }"
            >
            { template:do-create-resource('team-member', $enterprise, (), $form, ()) }
            </Added>
          else
            (),
      (: 2. remove Member from Team in every deleted Enterprise :)
      for $ref in $removed-ref
      let $enterprise := globals:collection('enterprises-uri')//Enterprise[Id eq $ref]
      return
        <Removed short="{ $enterprise/Information/ShortName }">
          { template:do-delete-resource('member-simple', $enterprise/Team/Members/Member[PersonRef eq $id], $enterprise) }
        </Removed>
      }
      </Feedback>
  
};

(: ======================================================================
   Create master personal Information block in account in case user
   becoming unaffiliated
   Pre-condition: must be called before removing from all teams
   ======================================================================
:)
declare function local:unaffiliate( $model as element(), $data as element() ) as element() {
  if (($data/GenericRoles[GenericRolesSelector eq 'on']) and ((count($data/GenericRoles/Roles/Role[FunctionRef = custom:get-roles-in-scope('enterprise')]) eq 0)
       and not(exists($data//Tokens/Static/Role))
       and not(exists($model/Information)))) then
    let $member := fn:head(globals:collection('enterprises-uri')//Enterprise/Team//Member[PersonRef eq $model/Id])
    return
      if ($member) then
        let $info := template:gen-document('person-information', 'create', <Member>{ $member/Information/* }</Member>)
        return
          if (local-name($info) ne 'error') then (
            update insert $info into $model,
            <success>Created unaffiliated user with data from { $member/ancestor::Enterprise/Information/ShortName/text() }</success>
            )
          else
            $info
      else (: not reachable ? :)
        oppidum:throw-error('CUSTOM', 'No previous member data from which to create the unaffiliated user !')
  else
    <success/>
};

(: ======================================================================
   
   ======================================================================
:)
declare function local:get-scaleup-roles-feedback( $account as element(), $actual as element(), $former as element() ) as element() {
  let $id := $account/Id
  let $inscope := custom:get-roles-in-scope('scaleup')
  let $actuals := $actual//Role[FunctionRef = $inscope]
  let $formers := $former//Role[FunctionRef = $inscope]
  return
    let $removed-ref := $formers/FunctionRef[not(. = $actuals/FunctionRef)]
    let $added-ref := $actuals/FunctionRef[not(. = $formers/FunctionRef)]
    let $still-ref := ($actuals/FunctionRef[not(. = ($removed-ref, $added-ref))])
    return
      <Feedback>
      {
        (
          (: Added roles :)
          for $ref in $added-ref
          return
            <Added>{ if ($ref eq '10') then 'Facilitator' else 'Monitor' }</Added>
          ,
          (: Updated roles :)
          for $ref in $still-ref
          return
            <Updated>{ if ($ref eq '10') then 'Facilitator' else 'Monitor' }</Updated>
          ,
          (: Removed roles :)
          for $ref in $removed-ref
          return
            <Removed>{ if ($ref eq '10') then 'Facilitator' else 'Monitor' }</Removed>
        )
      }
      </Feedback>
};

(: ======================================================================
   Return true if $funcion-ref is in $scope scope, false otherwise
   ====================================================================== 
:)
declare function local:role-has-scope-for( $function-ref as xs:string, $scope as xs:string ) as xs:boolean {
  let $scope-refs := globals:collection('global-info-uri')//Description[@Role = 'normative']/Selector[@Name eq 'Functions']//Option[@Scope eq $scope and  @Scope ne 'scaleup'][empty(@AdminPanel) or (@AdminPanel ne 'static')]/Value
  return
    if (exists($scope-refs)) then
      $function-ref = $scope-refs
    else
      false()
};

(: ======================================================================
   Return static Role(s) from the model to persist them after the updating
   Static role are shown in the profile modal window but cannot be edited here
   ====================================================================== 
:)
declare function local:filter-static-roles( $model as element() ) as element()* {
  let $keep-refs := globals:collection('global-info-uri')//Description[@Role = 'normative']/Selector[@Name eq 'Functions']//Option[@AdminPanel eq 'static' and  @Scope ne 'scaleup']/Value
  return
    if (exists($keep-refs)) then
      $model/UserProfile/Roles/Role[FunctionRef = $keep-refs]
    else
      ()
};

(: ======================================================================
   Updates a profile model in database
   Applies change in Team membership whether it is needed
   ======================================================================
:)
declare function local:do-update-profile( $model as element(), $data as element() ) as element()* {
  let $profile := $model/UserProfile
  let $cleaned := 
    (: prepare new Roles section for updating - TODO: data template ? :)
    <UserProfile>
      <Roles>
        {
        local:filter-static-roles($model),
        if ($data/GenericRoles[GenericRolesSelector eq 'on']) then
          for $role in $data/GenericRoles/Roles/Role
          let $fref := $role/FunctionRef
          return
            <Role>
              { 
              $fref,
              if (local:role-has-scope-for($fref, 'enterprise')) then
                $role/Enterprises/EnterpriseRef
              else if (local:role-has-scope-for($fref, 'program')) then
                $role/Programs/ProgramId
              else
                ()
              }
            </Role>
        else ()
        ,
        if (local:is-a-facilitator($data)) then
          <Role><FunctionRef>10</FunctionRef></Role> 
        else (),
        if (local:is-a-monitor($data)) then
          <Role><FunctionRef>11</FunctionRef></Role> 
        else () 
        }
      </Roles>
    </UserProfile>
  let $scaleupRolesFeedback := local:get-scaleup-roles-feedback($model, $cleaned, $profile)
  let $unaffiliate := local:unaffiliate($model, $data)  
  return 
    if (local-name($unaffiliate) eq 'success') then 
      let $post := local:create-delete-members($model, $cleaned, $profile)
      let $done := 
        if ($profile) then (: update or delete existing Roles :)
          if (exists($cleaned/Roles/Role)) then (: not empty :)
            if ($profile/Roles) then
              update replace $profile/Roles with $cleaned/Roles
            else
              update insert $cleaned/Roles into $profile
          else if ($profile/Roles) then
            update delete $profile/Roles 
          else
            ()
        else (: create UserProfile - seem unreachable ? :)
          if ($data/GenericRoles[GenericRolesSelector eq 'on']) then
            update insert <UserProfile>{ $data/GenericRoles/Roles }</UserProfile> into $model
          else ()
      return
        let $print :=
          string-join(
            (
            'Roles updated.',
            $unaffiliate/text(),
            if ($post/Added) then (
              concat('Added as team member inside ', string-join( $post/Added/@short, ', '), '.'),
              if ($post/Added/@complete = '1') then (
                'Personal information has been duplicated from a previous registration.',
                'You may check that data is relevant inside each team.'
                )
              else (
                'No previous personal information was available to fill the member record.',
                'Please complete it in each team.'
                )
              )
            else
              (),
            if ($post/Removed) then
              concat('Removed from enterprise(s) ', string-join( $post/Removed/@short, ','), '.')
            else
              ()
            ),
            '&#xa;&#xa;'
          )
          let $facilitorMonitorUpdate := template:do-update-resource("user_roles", (), $model, $data, <Form/>)  
        return
          if (local-name($facilitorMonitorUpdate) eq 'success') then 
            (
            let $print-final := 
              string-join(
                (
                  $print 
                  ,
                  if ($scaleupRolesFeedback//Added) then
                    concat('Added roles ', string-join($scaleupRolesFeedback//Added/text(), ', '), '.') 
                  else ()
                  ,
                  if ($scaleupRolesFeedback//Updated) then
                    concat('Updated roles ', string-join($scaleupRolesFeedback//Updated/text(), ', '), '.') 
                  else ()
                  ,
                  if ($scaleupRolesFeedback//Removed) then
                     concat('Removed roles ', string-join($scaleupRolesFeedback//Removed/text(), ', '), '.')
                  else ()
                ),
                '&#xa;&#xa;'
              )
            return
              ajax:report-success('INFO', $print-final, local:gen-ajax-payload($model, $data)))
          else
            $facilitorMonitorUpdate
    else
      $unaffiliate
};

(: ======================================================================
   Generate Role model for a role which can be changed in admin panel
   ====================================================================== 
:)
declare function local:gen-read-write-role( $role as element() ) as element() {
  if ($role/EnterpriseRef) then
    <Role>
      { $role/FunctionRef }
      <Enterprises>{ $role/EnterpriseRef }</Enterprises>
    </Role>
  else if ($role/ProgramId) then
    <Role>
      { $role/FunctionRef }
      <Programs>{ $role/ProgramId }</Programs>
    </Role>
  else
    $role
};

(: ======================================================================
   Generate Role model for a role which cannot be changed in admin panel
   ====================================================================== 
:)
declare function local:gen-static-role( $role as element() ) as element() {
  <Role>
    <Function>{ display:gen-name-for('Functions', $role/FunctionRef, 'en') }</Function>
    {
    if ($role/EnterpriseRef) then
      <Company>{ custom:gen-enterprise-name($role/EnterpriseRef, 'en') }</Company>
    else (: tries alternative :)
      <Company>
        { fn:collection($globals:admissions-uri)//Admission[Id eq $role/AdmissionKey]/CompanyProfile/CompanyName/text() }
      </Company>
    }
  </Role>
};


(: ======================================================================
   Generates 'Roles' or 'Static' model as per $root
   with the list of corresponding user roles in the $model
   ====================================================================== 
:)
declare function local:gen-roles-for-editing( $model as element()?, $root as xs:string ) as element()? {
  let $functions := globals:collection('global-info-uri')//Description[@Role = 'normative']/Selector[@Name eq 'Functions']
  let $roles := for $r in $model/UserProfile/Roles/Role[FunctionRef ne '10' and FunctionRef ne '11']
                let $panel := $functions//Option[Value eq $r/FunctionRef]/@AdminPanel
                where (($root eq 'Roles') and empty($panel))
                      or (($root eq 'Static') and ($panel eq 'static'))
                return $r
  return
    if (empty($roles)) then (: safeguard to avoid AXEL infinite loop in xt:repeat on <Roles/> :)
      ()
    else
      element { $root }
      {
      for $r in $roles
      return 
        if ($root eq 'Roles') then
          local:gen-read-write-role($r)
        else (: assuming Static :)
          local:gen-static-role($r)
      }
};

(: ======================================================================
   Asserts submitted profile data and updates model in database
   ====================================================================== 
:)
declare function local:update-profile( $model as element() ) {
  let $data := oppidum:get-data()
  let $checks := local:validate-profile-submission($data, $model)
  return
    if (every $c in $checks satisfies local-name($c) eq 'success') then
      local:do-update-profile($model, $data)
    else
      $checks
};

(: ======================================================================
   Implements POST profiles/{id} to update a permanent profile
   ====================================================================== 
:)
declare function local:POST-update-profile-by-id( $cmd as element() ) {
  let $id := string($cmd/resource/@name)
  let $model := globals:collection('persons-uri')//Person[Id = $id]
  return
    if ($model) then
      local:update-profile($model)         
    else
      ajax:throw-error('URI-NOT-SUPPORTED', ())
};

(: ======================================================================
   Implements GET profiles/{id} to edit a permanent profile
   ====================================================================== 
:)
declare function local:GET-read-profile-by-id-for-editing( $cmd as element() ) {
  let $id := string($cmd/resource/@name)
  let $model := globals:collection('persons-uri')//Person[Id = $id]
  let $calculatedRoles :=  local:gen-roles-for-editing($model, 'Roles')
  let $calculatedStaticRoles :=  local:gen-roles-for-editing($model, 'Static')
  return    
    <UserProfile>
      <GenericRoles>
         <GenericRolesSelector>
         {
          if ($calculatedRoles//Role[FunctionRef ne '10' and FunctionRef ne '11']) then
            "on"
          else
            "off"
         }         
         </GenericRolesSelector>
         { $calculatedRoles }
      </GenericRoles>
      <Tokens>
      { $calculatedStaticRoles }
      </Tokens>
      { template:gen-read-model("user_roles", $model, 'en') }
    </UserProfile>     
};

(: MAIN ENTRY POINT - CONTROLLER ROUTING :)
let $cmd := oppidum:get-command()
let $m := request:get-method()
let $target := string($cmd/resource/@name)
return
  (: FIXME: add access control :)
  if ($m eq 'POST') then
    (: POST profiles/{id} :)
    local:POST-update-profile-by-id($cmd)
  else
    local:GET-read-profile-by-id-for-editing($cmd)
