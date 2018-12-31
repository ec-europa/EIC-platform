xquery version "3.0";
(: ------------------------------------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors: Stéphane Sire <s.sire@opppidoc.fr>

   Team / Member search

   April 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace search = "http://oppidoc.com/ns/application/search";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";

(: ======================================================================
   Return the current ECAS e-mail if it exists in the user profile
   (account already created) or the team member e-mail otherwise.
   TODO: show a warning if account e-mail (ECAS) is different than member
   e-mail this could be shown only if [] show warnings box ticked
   ====================================================================== 
:)
declare function local:gen-key-email-for ( $m as element(), $profile as element()? ) as xs:string {
  let $eu-login := $profile//Email[@Name eq 'ECAS']
  let $contacts-email := $m/Information/Contacts/Email
  return 
    if (empty($eu-login)) then 
      concat($contacts-email, ' (contact)')
    else if ($eu-login ne $contacts-email) then
      concat($eu-login, ' (WARNING ', $contacts-email, ')')
    else
      $eu-login/text()
};

(: ======================================================================
   Generate fields common to all tables (except Pending Investor
   ====================================================================== 
:)
declare function local:gen-common-fields ( $cie as element(), $m as element(), $profile as element()?, $cache as map() ) as element()* {
  <Company>{ head(($cie/Information/ShortName/text(), $cie/Information/Name/text())) }</Company>,
  <CompanyId>{ $cie/Id/text() }</CompanyId>,
  <Role>
    {
    let $roles := custom:get-member-roles-for($profile, $cie/Id, $cache)
    return
       if (exists($roles)) then 
         display:gen-map-name-for('FunctionsBrief', $roles, $cache)
       else
         'none'
    }
  </Role>,
  <PO>
  {
    if ($cie/Projects) then
        let $po-cache := map:get($cache, 'project-officers')
        return
          string-join(
            for $PO-key in distinct-values($cie/Projects//ProjectOfficerKey)
            return map:get($po-cache, $PO-key),
            ', '
            )
    else if ($cie/Settings/Teams[text() eq 'Investor']) then
        'Investor'
    else
    ()
  }
  </PO>,
  if ($m/CreatedByRef ne '-1') then
    (: fn:collection($globals:enterprises-uri)//Member loop invariant inside ! :)
    <CreatedBy>{ custom:gen-person-name($m/CreatedByRef, 'en') }</CreatedBy>
  else
    ()
};

(: ======================================================================
   Generate table row for delegates table
   ======================================================================
:)
declare function search:gen-member-sample ( $m as element(), $profile as element()?, $cache as map() ) as element() {
  let $info := $m/Information
  let $cie := $m/ancestor::Enterprise
  let $index := $m/Id/text()
  return
    <Users>
      <Id>{ concat($index, '_', $cie/Id) }</Id>
      <MemberId>{ $index }</MemberId>
      <Name>{ concat($info/Name/LastName, ' ', $info/Name/FirstName) }</Name>
      <Key>
        { 
          try 
          {
            local:gen-key-email-for($m, $profile)
          }
          catch *
          {
            concat('[Error] - Company ', $cie/Id/text(), ' has no member')
          }
        }
      </Key>
      { local:gen-common-fields($cie, $m, $profile, $cache) }
      <Access>
        { 
        (: display:gen-name-for-sref('AccessLevels', custom:gen-member-access-level($m), 'en') :)
        (: TODO: gen-profile-access-level($profile) :)
        custom:gen-member-access-level($m,$profile)
        (: Quick & Dirty : sends code for JS decoding to turn into buttons :)
        }
      </Access>
    </Users>
};

(: ======================================================================
   Generate table row for unaffiliated users table
   ======================================================================
:)
declare function search:gen-unaffiliated-sample ( $m as element(), $profile as element()?, $cache as map() ) as element() {
  let $info := $m/Information
  return
    <Users>
      <Name>{ concat($info/Name/LastName, ' ', $info/Name/FirstName) }</Name>
      <Key>
        { 
          try 
          {
            local:gen-key-email-for($m, $profile)
          }
          catch * {
            concat('[Error] - No user has been found')
          }
        }
      </Key>
      <Role>
        {
        let $roles := custom:get-member-roles-for($profile, '-1', $cache)
        return
           if (exists($roles)) then 
             display:gen-map-name-for('FunctionsBrief', $roles, $cache)
           else
             'none'
        }
      </Role>
      {
      if ($m/CreatedByRef ne '-1') then
        (: fn:collection($globals:enterprises-uri)//Member loop invariant inside ! :)
        <CreatedBy>{ custom:gen-person-name($m/CreatedByRef, 'en') }</CreatedBy>
      else
        ()
      }
      <Access>
        { 
        if ($profile/Blocked) then
          '4' (: blocked :)
        else if ($profile/Remote[@Name eq 'ECAS'] or $profile/Email[@Name eq 'ECAS'] or $profile/Username) then 
          '3' (: authorized :)
        else (: for debug purpose ? :)
          '99' (: unknown :)
        }
      </Access>
    </Users>
};

(: ======================================================================
   Generates Enterprise information fields to display in result table
   FIXME: finish specification of Role (implement with StatusHistory ?)
   ======================================================================
:)
declare function search:gen-token-sample ( $m as element(), $profile as element()?, $cache as map() ) as element() {
  let $info := $m/Information
  let $cie := $m/ancestor::Enterprise
  let $index := $m/Id/text()
  return
    <Users>
      <Id>{ concat($index, '_', $cie/Id) }</Id>
      <PersonId>{ $profile/../Id/text() }</PersonId>
      { 
      let $token := enterprise:get-last-scaleup-request($cie)
      return
        if ($token/TokenStatusRef eq '3') then
          <CurToken>{ $token/Email/text() }</CurToken>
        else (:if (exists(enterprise:get-token-owner-person-for($cie))) then
          <CurToken>not in TokenHistory</CurToken>
        else:)
          ()
      }
      <Key>{ $m/Information/Contacts/Email/text() }</Key>
      { 
      local:gen-common-fields($cie, $m, $profile, $cache),
      if (empty($profile)) then
        <Access>-1</Access>
      else if ($profile//Role[FunctionRef eq '8'][EnterpriseRef eq $cie/Id]) then
        <Access>3</Access>
      else 
        let $last := enterprise:get-most-recent-request($cie, $profile/../Id)
        return
          if (exists($last)) then 
            <Access>{ $last/TokenStatusRef/text() }</Access>
          else
            (),
      if (exists($profile//Remote[@Name eq 'ECAS'])) then (: useful for debugging :)
        <EULogin>{ $profile//Remote[@Name eq 'ECAS']/text() }</EULogin>
      else
        ()
      }
    </Users>
};

(: ======================================================================
   Dumps all unaffiliated users in database
   ======================================================================
:)
declare function local:fetch-all-unaffiliated ( $cache as map(), $func ) as element()* 
{
  for $m in fn:collection($globals:persons-uri)//Person[exists(Information)]
  let $profile := $m/UserProfile
  order by $m/Information/Name/LastName
  return
    $func($m, $profile, $cache)
};

(: ======================================================================
   Dumps all enterprises in database
   ======================================================================
:)
declare function local:fetch-all-members ( $cache as map(), $func ) as element()* 
{
  let $members := fn:collection($globals:enterprises-uri)
  let $persons := fn:collection($globals:persons-uri)
  for $m in $members//Member
  let $profile := if ($m/PersonRef) then $persons//Person[Id eq $m/PersonRef]/UserProfile else ()
  order by $m/Information/Name/LastName
  return
    $func($m, $profile, $cache)
};

(: ======================================================================
   Converts a list of project officers person references to a list 
   of project officers keys (since they are recorderd with their key in Projects)
   See also import-po.xql and "project-officer" data template
   ====================================================================== 
:)
declare function local:get-po-keys-from-refs( $officers as xs:string* ) as xs:string* {
  for $po in fn:collection($globals:persons-uri)//Person[Id = $officers]//Remote[@Name eq 'ECAS']
  return $po/text()
};

(: ======================================================================
   Implement Access level criteria for delegates table
   See also custom:gen-member-access-level, AccessLevels in global-information.xml
   TODO: switch to a StatusHistory based implementation ?
   ====================================================================== 
:)
declare function local:match-access-level( $member as element(), $profile as element()?, $levels as xs:string+ ) as xs:boolean {
  some $l in $levels satisfies
    if ($l = '2') then (: Rejected :)
      exists($member/Rejected)
    else if ($l = '4') then (: Blocked :)
      exists($profile/Blocked)
    else if ($l = '3') then (: Authorized ~ note Rejected implies no Person profile :)
      empty($profile/Blocked) and 
      (exists($profile/Email[@Name eq 'ECAS']) or exists($profile/Remote[@Name eq 'ECAS']) or exists($profile/Username))
    else if ($l = '1') then (: Pending :)
      empty($profile) and not($member/Rejected)
    else if ($l = '99') then (: for debug - to be refined ? :)
      exists($profile) and 
      not(exists($profile/Email[@Name eq 'ECAS']) or exists($profile/Remote[@Name eq 'ECAS']) or exists($profile/Username))
    else
      false()
};

(: ======================================================================
   Implement Access level criteria for tokens table
   See also custom:gen-member-access-level, AccessLevels in global-information.xml
   TODO: switch to a StatusHistory based implementation ?
   ====================================================================== 
:)
declare function local:match-token-access-level( $member as element(), $profile as element()?, $levels as xs:string+ ) as xs:boolean {
  (: TODO: only test using the last TokenRequest ? :)
  if (exists($profile)) then
    let $cie := $member/ancestor::Enterprise
    let $last := enterprise:get-most-recent-request($cie, $profile/../Id)
    return
      empty($levels)
      or
      (some $l in $levels satisfies
        if ($l = '3') then
          $profile//Role[FunctionRef eq '8'][EnterpriseRef eq $cie/Id]
        else
          $l eq $last/TokenStatusRef)
  else
    false()
};

(: ======================================================================
   Checks profile against functions
   ====================================================================== 
:)
declare function local:match-function( $profile as element()?, $functions as xs:string+ ) as xs:boolean {
  if (exists($profile)) then
      $profile//FunctionRef = $functions
  else (: everything else defaults to Delegate, should imply Pending access level :)
    $functions = '4'
    (: Hard-coded Delegate function :)
};

(: ======================================================================
   Dumps a subset of enterprise filtered by criterias
   ======================================================================
:)
declare function local:fetch-some-members ( $filter as element(), $cache as map(), $func1, $func2 ) as element()*
{
  let $funding := $filter//FundingProgramRef
  let $pid := $filter//ProjectId
  let $acronym := $filter//Acronym
  let $termination := $filter//TerminationFlagRef
  let $validity := $filter//StatusFlagRef[text() ne '2']
  let $valid := $filter//StatusFlagRef[text() eq '2']
  let $type := $filter//CompanyTypeRef
  let $direct := exists($filter//PersonKey)
  let $person := $filter//PersonKey[matches(., '^\d+$')]
  let $mail := $filter//PersonKey[not(. = $person)]
  let $enterprise := $filter//EnterpriseRef
  let $officer := local:get-po-keys-from-refs($filter//ProjectOfficerRef)
  let $level := $filter//StatusRef
  let $function := $filter//FunctionRef
  let $check-profile := not(empty($level)and empty($function))
  let $members := fn:collection($globals:enterprises-uri)
  let $persons := fn:collection($globals:persons-uri)
  return
    for $m in $members//Member
    let $e := $m/ancestor::Enterprise
    let $p := $e/Projects/Project
    let $profile := if ($m/PersonRef) then $persons//Person[Id eq $m/PersonRef]/UserProfile else ()
    where (not($direct) or ((exists($person) and $m/PersonRef = $person) or (exists($mail) and $m//Email = $mail)))
      and (empty($enterprise) or $m/ancestor::Enterprise/Id = $enterprise)
      and (empty($pid) or $p/ProjectId = $pid)
      and (empty($acronym) or $p/ProjectId = $acronym)
      and (empty($funding) or $p/Call/FundingProgramRef = $funding)
      and (empty($termination) or $p//TerminationFlagRef = $termination)
      and (empty($validity) or $e//StatusFlagRef = $validity)
      and (empty($valid) or $e//StatusFlagRef = $valid or string-join($e//StatusFlagRef, '') eq '')
      and (empty($type) or enterprise:organisation-is-a($e, $type))
      and (empty($officer) or $m/ancestor::Enterprise//Project/ProjectOfficerKey = $officer)
      and (empty($level) or $func1($m, $profile, $level))
      and (empty($function) or local:match-function($profile, $function))
    return
      $func2($m, $profile, $cache)
};

(: ======================================================================
   Returns Enterprise(s) matching request with request timing
   ======================================================================
:)
declare function search:fetch-delegates ( $request as element(), $cache as map() ) as element()* {
  if (count($request/*/*) + count($request/*[local-name(.)][normalize-space(.) != '']) = 0) then (: empty request :)
    local:fetch-all-members($cache, function-lookup(xs:QName("search:gen-member-sample"), 3))
  else
    local:fetch-some-members($request, $cache, 
        function-lookup(xs:QName("local:match-access-level"), 3), 
        function-lookup(xs:QName("search:gen-member-sample"), 3))
};

(: ======================================================================
   Returns all Unaffiliated users
   ======================================================================
:)
declare function search:fetch-unaffiliated ( $request as element(), $cache as map() ) as element()* {
  local:fetch-all-unaffiliated($cache, function-lookup(xs:QName("search:gen-unaffiliated-sample"), 3))
};


(: ======================================================================
   Return rows for the tokens allocation table

   This search implies some Access level (e.g. Pending) 
   ======================================================================
:)
declare function search:fetch-tokens ( $request as element(), $cache as map() ) as element()* {
  if (count($request/*/*) = 0) then (: empty request :)
    local:fetch-all-members($cache, function-lookup(xs:QName("search:gen-token-sample"), 3))
  else
    local:fetch-some-members($request, $cache,
      function-lookup(xs:QName("local:match-token-access-level"), 3),
      function-lookup(xs:QName("search:gen-token-sample"), 3))
};

(: ======================================================================
                      DEPRECATED - Pending Investor
   ======================================================================
:)

(: ======================================================================
   DEPRECATED - Generate table row for pending investor table
   Parameters:
   - $inv : Investor
   - $admission : Admission form associated with this investor
   - $cache:  in-memory cache to speed up page rendering by reducing
              the amount of database lookup operations
   ======================================================================
:)
declare function search:gen-pending-investor-sample ( $inv as element(), $admission as element()?, $cache as map() ) as element() {
  let $idInv := $inv/Id/text()
  let $idAdmission := $admission/Id/text()
  let $isInvestor := $admission/Settings/Teams eq 'Investor' (: legacy form :)
  let $profile := $inv/UserProfile
  return
    <Users>
      <Id>{ $idInv }</Id>
      <PersonId>{ $idInv }</PersonId>
      <Name>{ concat($admission/ParticipantInformation/LastName, ' ', $admission/ParticipantInformation/FirstName) } </Name>
      
      <CreatedBy>{ concat($admission/ParticipantInformation/LastName, ' ', $admission/ParticipantInformation/FirstName) }</CreatedBy><Key>
      { 
        (: shows a warning if different than $info/Contacts/Email/text()
           could be shown only if [] show warnings box ticked :)
        let $eu-login := $inv/UserProfile/Email[@Name eq 'ECAS']
        let $contacts-email := $admission/ParticipantInformation/Email
        return 
          if (empty($eu-login)) then 
            $contacts-email/text()
          else if ($eu-login ne $contacts-email) then
            concat($eu-login, ' (WARNING ', $contacts-email, ')')
          else
            $eu-login/text()
        }
      </Key> 
      <Company>
        { 
        if ($isInvestor) then
          head($admission/CompanyProfile/CompanyName/text()) 
        else if ($admission/OrganisationList//EnterpriseRef or $admission/CreateOrganisation/OrganisationInformation/Name) then
          (: temporary: TODO 1 line per join or create :)
          string-join(
            (
            for $org in $admission/OrganisationList//EnterpriseRef
            return concat(custom:gen-enterprise-name($org, 'en'), ' (join)'),
            if ($admission/CreateOrganisation/OrganisationInformation/Name) then
              concat($admission/CreateOrganisation/OrganisationInformation/Name, ' (new)')
            else
              ()
            ), ', '
            )
        else
          '-'
        }
      </Company>
      <AdmissionId>{ $idAdmission }</AdmissionId>
      <Role>
      {
        if ($profile//FunctionRef[text() eq '7']) then
            'Investor'
        else if ($profile//FunctionRef[text() eq '9']) then
          if ($isInvestor) then
            'Pending investor'
          else
            'Pending user'
        else
            'Unknown'
      }
      </Role>,
       
      <Access>{
        if (not($isInvestor)) then (: temporary :)
            '0' (: to be implemented :)
        else if ($profile/Blocked) then
            '4' (: blocked :)
        else if (($profile//FunctionRef[text() eq '9']) and (($profile/Remote[@Name eq 'ECAS'] or $profile/Email[@Name eq 'ECAS'] or $profile/Username))) then 
            '1' (: Pending :)
         else if (($profile//FunctionRef[text() eq '7']) and (($profile/Remote[@Name eq 'ECAS'] or $profile/Email[@Name eq 'ECAS'] or $profile/Username))) then 
            '3' (: Authorized :)
        else (: for debug purpose ? :)
            '99' (: unknown :)}
      </Access>
      <Admission>{
        if ($admission//AdmissionStatusRef eq '1') then
            '1' (: Draft :)
        else if (($admission//AdmissionStatusRef eq '2') or not($admission//AdmissionStatusRef)) then
            '2' (: Submitted :)
        else if ($admission//AdmissionStatusRef eq '3') then
            '3' (: Rejected :)
        else if ($admission//AdmissionStatusRef eq '4') then
            '4' (: Authorized :)
        else (: for debug purpose ? :)
            '99' (: unknown :)
        }
      </Admission>
    </Users>
};

(: ======================================================================
    DEPRECATED - Returned the admission with the given ID
    Parameters:
    - ID: id of the targeted admission
    
    Return: The admission
   ======================================================================
:)
declare function local:get-admission-from-id( $id as xs:string ) as element()* {
    let $admissions := fn:collection($globals:admissions-uri) 
    for $admission in $admissions
    where exists($admission//.[Id eq $id])
    group by $admission
    return $admission/*
};

(: ======================================================================
   DEPRECATED - Get all pending investors from database
   - Return all Pending Investor 
   
   Sample of pending investor :
   <Person>
    <Id>4013</Id>
    <UserProfile>
        <Email Name="ECAS">franck.leple@amplexor.com</Email>
        <Roles>
            <Role>
                <FunctionRef>9</FunctionRef>
                <AdmissionKey>1</AdmissionKey>
            </Role>
        </Roles>
    </UserProfile>
   </Person>
   ======================================================================
:)
declare function local:fetch-all-pending-investors ( $cache as map()) as element()* {
  let $persons := fn:collection($globals:persons-uri)
  for $inv in $persons//Person[descendant::FunctionRef eq '9']
  let $admission := local:get-admission-from-id($inv//AdmissionKey[parent::Role[FunctionRef eq '9']][1])
  order by $inv/Id
  return
    search:gen-pending-investor-sample($inv, $admission, $cache)
};

(: ======================================================================
   DEPRECATED - Implement Access level criteria for pending-investor table
   NOT USED
   ====================================================================== 
:)
declare function local:match-pending-investor-access-level( $inv as element(), $admission as element()?, $levels as xs:string+ ) as xs:boolean {
    let $profile := $inv/UserProfile
    return 
      if ($profile//Role[FunctionRef eq '9']) then
        true()
      else
        false()
};

(: ======================================================================
   DEPRECATED - Dumps a subset of pending investor filtered by criterias
   ======================================================================
:)
declare function local:fetch-some-pending-investors ( $filter as element(), $cache as map()) as element()*
{
  let $persons := fn:collection($globals:persons-uri)
  for $inv in $persons//Person[descendant::FunctionRef eq '9']
    let $admission := local:get-admission-from-id($inv//AdmissionKey[parent::Role[FunctionRef eq '9']][1])
    order by $inv/Id
    (:where (local:match-pending-investor-access-level($inv, $admission, "")):)
    return
      search:gen-pending-investor-sample($inv, $admission, $cache)
};

(: ======================================================================
   DEPRECATED - Return rows for the investors accreditation table

   Parameters:
   - $request: Payload cf oppidum:get-data()
   - $cache:  in-memory cache to speed up page rendering by reducing
              the amount of database lookup operations
   
   Return:
   - set of elements, each element represent a table's row and a Pending
     Investor
   ======================================================================
:)
declare function search:fetch-investors ( $request as element(), $cache as map() ) as element()* {
  if (count($request/*/*) = 0) then (: empty request :)
    local:fetch-all-pending-investors($cache)
  else
    local:fetch-some-pending-investors($request, $cache)
};

(: ======================================================================
                          Pending users 
   ======================================================================
:)

(: ======================================================================
   Generate table row for pending user table
   Parameters:
   - $inv : user
   - $admission : Admission form associated with this investor
   - $cache:  in-memory cache to speed up page rendering by reducing
              the amount of database lookup operations
   ======================================================================
:)
declare function search:gen-pending-user-sample ( $user as element(), $admission as element()? ) as element() {
  let $idInv := $user/Id/text()
  let $idAdmission := $admission/Id/text()
  let $profile := $user/UserProfile
  let $deprecated := exists($admission/Settings/Teams)
  return
    <Users>
      <Id>{ $idInv }</Id>
      <PersonId>{ $idInv }</PersonId>
      <Name>{ concat($admission/ParticipantInformation/LastName, ' ', $admission/ParticipantInformation/FirstName) } </Name>
      
      <CreatedBy>{
                  if(exists($admission/EULogin)) then
                    concat($admission/EULogin/LastName, ' ', $admission/EULogin/FirstName)
                  else
                    concat($admission/ParticipantInformation/LastName, ' ', $admission/ParticipantInformation/FirstName)
                  }
     </CreatedBy> 
     <Key>
      { 
        (: shows a warning if different than $info/Contacts/Email/text()
           could be shown only if [] show warnings box ticked :)
        let $eu-login := $user/UserProfile/Email[@Name eq 'ECAS']
        let $contacts-email := $admission/ParticipantInformation/Email
        return 
          if (empty($eu-login)) then 
            $contacts-email/text()
          else if ($eu-login ne $contacts-email) then
            concat($eu-login, ' (WARNING ', $contacts-email, ')')
          else
            $eu-login/text()
        }
      </Key> 
      <Company>
        { 
        if ($admission/OrganisationList//EnterpriseRef or $admission/CreateOrganisation/OrganisationInformation/Name) then
          (: temporary: TODO 1 line per join or create :)
          
            string-join(
              (
              $admission/OrganisationList//EnterpriseRef ! custom:gen-enterprise-name(., 'en'),
              if ($admission/CreateOrganisation/OrganisationInformation/Name) then
                $admission/CreateOrganisation/OrganisationInformation/Name
              else
                ()
              ), 
              ', ' 
            )
        else if ($deprecated) then
          string($admission/CompanyProfile/CompanyName)
        else
          '-'
        }
      </Company>
      <AdmissionId>{ $idAdmission }</AdmissionId>
      <Role>
      {
        if ($profile//FunctionRef[text() eq '7']) then
            'Investor'
        else if ($profile//FunctionRef[text() eq '9']) then
            'Pending user'
        else if ($profile//FunctionRef[text() eq '4']) then
            'Delegate'
         else
            'Unknown'
      }
      </Role>,
      <OrganisationTypes>
         { 
        if ($admission/OrganisationList//EnterpriseRef or $admission/CreateOrganisation/OrganisationInformation/Name) then
          (: temporary: TODO 1 line per join or create :)
          
            string-join(
              (
              $admission/OrganisationList//EnterpriseRef ! enterprise:organisationType(.),
              if ($admission/CreateOrganisation/OrganisationInformation/Name) then
                enterprise:organisationTypeFromAdmission($admission)
              else
                ()
              ), 
              ', ' 
            )
        else if ($deprecated) then
          'Investor'
        else
          '-'
       }
      </OrganisationTypes>
      <OrganisationStatus>{
        if ($admission/OrganisationList//EnterpriseRef or $admission/CreateOrganisation/OrganisationInformation/Name) then
          (: temporary: TODO 1 line per join or create :)
            string-join(
              (
              $admission/OrganisationList//EnterpriseRef ! 'Existing',
              if ($admission/CreateOrganisation/OrganisationInformation/Name) then
                'New'
              else
                ()
              ), 
              ', ' 
            )
        else if ($deprecated) then
          ' (deprecated investor)'
        else
          '-'
      }</OrganisationStatus>   
      <Date>{
            if(exists($admission/@Creation)) then 
              display:gen-display-date-format($admission/@Creation,'yyyy/mm/dd')
            else
            '-'
            }</Date>
      <Access>{
        if ($profile/Blocked) then
            '4' (: blocked :)
        else if (($profile//FunctionRef[text() eq '9']) and (($profile/Remote[@Name eq 'ECAS'] or $profile/Email[@Name eq 'ECAS'] or $profile/Username))) then 
            '1' (: Pending :)
         else if ((($profile//FunctionRef[text() eq '7']) or ($profile//FunctionRef[text() eq '4']) ) and (($profile/Remote[@Name eq 'ECAS'] or $profile/Email[@Name eq 'ECAS'] or $profile/Username))) then 
            '3' (: Authorized :)
        else (: for debug purpose ? :)
            '99' (: unknown :)}
      </Access>
      <Admission>{
        if (not($admission/MyOrganisationProfile/MyOrganisationsTypes) and ($admission//AdmissionStatusRef eq '2')) then
            '98' (: Obsolete formular must be rejected :)
        else if ($admission//AdmissionStatusRef eq '1') then
            '1' (: Draft :)
        else if (($admission//AdmissionStatusRef eq '2') or not($admission//AdmissionStatusRef)) then
            '2' (: Submitted :)
        else if ($admission//AdmissionStatusRef eq '3') then
            '3' (: Rejected :)
        else if ($admission//AdmissionStatusRef eq '4') then
            '4' (: Authorized :)
        else (: for debug purpose ? :)
            '99' (: unknown :)
        }
      </Admission>
      {
      if ($deprecated) then 
        <Deprecated>1</Deprecated>
      else
        ()
      }
    </Users>
};

(: ======================================================================
   Get all pending users from database
   Return all pending users including DEPRECATED investors (but they don't have Action)
   
   Sample of pending users :
   <Person>
    <Id>4013</Id>
    <UserProfile>
        <Email Name="ECAS">franck.leple@amplexor.com</Email>
        <Roles>
            <Role>
                <FunctionRef>9</FunctionRef>
                <AdmissionKey>1</AdmissionKey>
            </Role>
        </Roles>
    </UserProfile>
   </Person>
   ======================================================================
:)
declare function local:fetch-all-pending-users ( $cache as map()) as element()* {
  
  
  let $persons := fn:collection($globals:persons-uri)
  for $user in $persons//Person[descendant::FunctionRef eq '9']
  let $admission := local:get-admission-from-id($user//AdmissionKey[parent::Role[FunctionRef eq '9']][1])
  order by $user/Id
  (:where ($admission/OrganisationList//EnterpriseRef or $admission/CreateOrganisation/OrganisationInformation/Name):)
  return
    search:gen-pending-user-sample($user, $admission)
};

(: ======================================================================
   Implement Access level criteria for pending-users table
   NOT USED
   ====================================================================== 
:)
declare function local:match-pending-users-access-level( $user as element(), $admission as element()?, $levels as xs:string+ ) as xs:boolean {
    let $profile := $user/UserProfile
    return 
      if ($profile//Role[FunctionRef eq '9']) then
        true()
      else
        false()
};

(: ======================================================================
   Dumps a subset of pending users filtered by criterias
   ======================================================================
:)
declare function local:fetch-some-pending-users ( $filter as element()) as element()*
{
 let $funding := $filter//FundingProgramRef
  let $pid := $filter//ProjectId
  let $acronym := $filter//Acronym
  let $termination := $filter//TerminationFlagRef
  let $enterprise := $filter//EnterpriseRef
  let $filterOrgaType := $filter//CompanyTypeRef
  let $filterstatusAdmission := $filter//StatusAdmissionRef
  let $officer := local:get-po-keys-from-refs($filter//ProjectOfficerRef)
  let $enterprises := globals:collection('enterprises-uri')
  let $persons := fn:collection($globals:persons-uri)
  for $user in $persons//Person[descendant::FunctionRef eq '9']
    let $admission := local:get-admission-from-id($user//AdmissionKey[parent::Role[FunctionRef eq '9']][1])
    let $orgaType := if ($admission) then 
                        string-join(
                                      (
                                      $admission/OrganisationList//EnterpriseRef ! enterprise:organisationType(.),
                                      if ($admission/CreateOrganisation/OrganisationInformation/Name) then
                                        enterprise:organisationTypeFromAdmission($admission)
                                      else
                                        ()
                                      ), 
                                      ', ' 
                                   )
                     else ()
    let $orgaTypeSequence :=
    (
    if(contains($orgaType,'Investor')) then
    ('3','2')
    else (),
    if(contains($orgaType,'Corporate')) then
    ('4','2')
    else (),
    if(contains($orgaType,'Beneficiary')) then
    '1'
    else ()
    )
    let $e := $enterprises//Enterprise[Id = $admission//EnterpriseRef]
    let $p := $e/Projects/Project
    order by $user/Id
    (:where (local:match-pending-users-access-level($user, $admission, "")):)
    where  
    (empty($enterprise) or $admission//EnterpriseRef = $enterprise)
    and   (empty($pid) or $p/ProjectId = $pid)
    and (empty($acronym) or $p/ProjectId = $acronym)
    and (empty($funding) or $p/Call/FundingProgramRef = $funding)
    and (empty($termination) or $p//TerminationFlagRef = $termination)
    and (empty($officer) or $p/ProjectOfficerKey = $officer)
    and (empty($filterOrgaType) or $orgaTypeSequence = $filterOrgaType)
    and (empty($filterstatusAdmission) or $admission//AdmissionStatusRef = $filterstatusAdmission)
    
    return
      search:gen-pending-user-sample($user, $admission)
};


(: ======================================================================
   Return rows for the users accreditation table

   Parameters:
   - $request: Payload cf oppidum:get-data()
   - $cache:  in-memory cache to speed up page rendering by reducing
              the amount of database lookup operations
   
   Return:
   - set of elements, each element represent a table's row and a Pending
     user
   ======================================================================
:)
declare function search:fetch-entries ( $request as element() ) as element()* {
    local:fetch-some-pending-users($request)
};
