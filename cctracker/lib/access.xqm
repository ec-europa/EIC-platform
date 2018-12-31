xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC XQuery Content Management Framework

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Access control engine implemented as XQuery functions

   To be use to control :
   - display of command buttons in the user interface
   - fine grain access to CRUD controllers

   Conventions:
   - access:assert-* : low-level functions implementing access control mini-language (see application.xml)
   - assert:check-* : high-level boolean functions to perform a check

   Do not forget to also set mapping level <access> rules to prevent URL forgery !

   January 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace access = "http://oppidoc.com/oppidum/access";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";

(: ======================================================================
   Returns the Id of the current user or () if the current user
   is not associated with a person in the databse.
   ======================================================================
:)
declare function access:get-current-person-id () as xs:string? {
  access:get-current-person-id (oppidum:get-current-user())
};

(: ======================================================================
   @return The UserProfile element representing current user or the empty sequence
   ====================================================================== 
:)
declare function access:get-current-person-profile() as element()? {
  let $realm := oppidum:get-current-user-realm()
  let $user := oppidum:get-current-user()
  return
    if (empty($realm) or ($realm eq 'EXIST')) then
      fn:collection($globals:persons-uri)//Person/UserProfile[Username eq $user]
    else
      fn:collection($globals:persons-uri)//Person/UserProfile[Remote[@Name eq $realm] eq $user]
};

(: ======================================================================
   Variant of the above function when the current user is known
   ======================================================================
:)
declare function access:get-current-person-id ( $user as xs:string ) as xs:string? {
  let $realm := oppidum:get-current-user-realm()
  return
    if (empty($realm) or ($realm eq 'EXIST')) then
      fn:collection($globals:persons-uri)//Person/UserProfile[Username eq $user]/../Id/text()
    else
      fn:collection($globals:persons-uri)//Person/UserProfile[Remote[@Name eq $realm] eq $user]/../Id/text()
};

(: ======================================================================
   Returns the list of region references current user is in charge in a given role
   (the in charge relation is coded with the RegionalEntityRef element)
   ====================================================================== 
:)
declare function access:get-current-user-regions-as ( $role as xs:string ) as element()* {
  let $realm := oppidum:get-current-user-realm()
  let $user := oppidum:get-current-user()
  let $role := access:get-function-ref-for-role($role)
  return
    if (empty($realm) or ($realm eq 'EXIST')) then
      fn:collection($globals:persons-uri)//Person/UserProfile[Username eq $user]//Role[FunctionRef eq $role]/RegionalEntityRef
    else
      fn:collection($globals:persons-uri)//Person/UserProfile[Remote[@Name eq $realm] eq $user]//Role[FunctionRef eq $role]/RegionalEntityRef
};

(: ======================================================================
   Returns the list of nuts current user is able to see in a given role
   (the in charge relation is coded with the NutsRef element)
   ====================================================================== 
:)
declare function access:get-current-user-nuts-as ( $role as xs:string ) as element()* {
  let $realm := oppidum:get-current-user-realm()
  let $user := oppidum:get-current-user()
  let $role := access:get-function-ref-for-role($role)
  return
    if (empty($realm) or ($realm eq 'EXIST')) then
      fn:collection($globals:persons-uri)//Person/UserProfile[Username eq $user]//Role[FunctionRef eq $role]//NutsRef
    else
      fn:collection($globals:persons-uri)//Person/UserProfile[Remote[@Name eq $realm] eq $user]//Role[FunctionRef eq $role]//NutsRef
};

(: ======================================================================
   Rules to create an Enterprise
   ======================================================================
:)
declare function access:check-enterprise-create() as xs:boolean {
  let $user := oppidum:get-current-user()
  let $groups := oppidum:get-current-user-groups()
  return
    ('users' = $groups)
};

(: ======================================================================
   Rules to delete an Enterprise : any member of the users group (anyone who has a login)
   The delete protocol will first check the Enterprise is not referenced anywhere
   ======================================================================
:)
declare function access:check-enterprise-delete() as xs:boolean {
  let $user := oppidum:get-current-user()
  let $groups := oppidum:get-current-user-groups()
  return
    ('users' = $groups)
};

(: ======================================================================
   Returns true if current user can update at least the person
   ======================================================================
:)
declare function access:check-person-update-at-least( $cur-user-ref as xs:string, $person as element() ) as xs:boolean {
  $cur-user-ref eq $person/Id/text()
};

(: ======================================================================
   Returns true if current user can update the person
   ======================================================================
:)
declare function access:check-person-update( $person as element() ) as xs:boolean {
  access:check-omnipotent-user-for('create', 'Person')
  or
  access:check-person-update-at-least(access:get-current-person-id(), $person)
};

(: ======================================================================
   Returns true if the transition is allowed for case or activity for current user,
   or false otherwise
   Pre-condition :
   YOU MUST obtain the transition by a call to workflow:get-transition-for() to be sure
   the transition is feasible from the current state, otherwise you will not be able
   to interpret the false result
   ======================================================================
:)
declare function access:check-status-change( $transition as element(), $project as element(), $case as element()?, $activity as element()? ) as xs:boolean {
  let $status :=
    if ($activity) then
      $activity/StatusHistory/CurrentStatusRef/text()
    else
      $case/StatusHistory/CurrentStatusRef/text()
  return
    if ($transition/@From = $status) then (: see pre-condition :)
      access:assert-access-rules($transition, $project, $case, $activity)
    else
      false()
};

(: ======================================================================
   Rules to upload an appendix
   NOT USED - CAN BE REMOVED
   ======================================================================
:)
declare function access:check-appendix-upload( $case as element(), $activity as element() ) as xs:boolean {
  let $user := oppidum:get-current-user()
  let $groups := oppidum:get-current-user-groups()
  let $uid := access:get-current-person-id($user)
  return
    ($uid = $activity/FundingRequest/ResponsibleCoach/CoachRef/text())
    or ($uid = $case/ResponsibleCoachRef/text())
    or ('admin-system' = $groups)
    or ('admin-finance' = $groups)
};

(: ======================================================================
   Rules to allow or not to delete an Annex represented by $item
   NOT USED - CAN BE REMOVED
   ======================================================================
:)
declare function access:check-appendix-delete( $item as element()? ) as xs:boolean {
  let $user := oppidum:get-current-user()
  let $groups := oppidum:get-current-user-groups()
  let $uid := access:get-current-person-id($user)
  return
    (('admin-system') = $groups) or ($item/SenderRef/text() eq $uid)
};

(: ======================================================================
   Tests current user is compatible with semantic role given as parameter
   See also default email recipients list generation in workflow/alert.xql
   ======================================================================
:)
declare function access:assert-semantic-role( $suffix as xs:string, $project as element(), $case as element()?, $activity as element()? ) as xs:boolean {
  let $group-ref := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role eq $suffix]/Id/text()
  let $pid := access:get-current-person-id() 
  return
    if ($pid) then
      if ($suffix eq 'region-manager') then
        let $region-entity := $case/ManagingEntity/RegionalEntityRef/text()
        return
          $pid = fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[(FunctionRef eq $group-ref) and (RegionalEntityRef eq $region-entity)]]/Id/text()
      else if ($suffix eq 'kam') then
        $pid = $case/Management/AccountManagerRef/text()
      else if ($suffix eq 'coach') then
        $pid = $activity/Assignment/ResponsibleCoachRef/text()
      else if ($suffix eq 'service-head') then
        let $service := $activity/Assignment/ServiceRef/text()
        return
          $pid = fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[(FunctionRef eq $group-ref) and (ServiceRef eq $service)]]/Id/text()
      else if ($suffix eq 'project-officer') then
        $pid = ($project/Information/ProjectOfficerRef/text(), $project/Information/BackupProjectOfficerRef/text())
      else
        false()
    else
      false()
};

(: ======================================================================
   Returns true if the user has only the role
   ======================================================================
:)
declare function local:assert-current-exclusive-role( $role as xs:string ) as xs:boolean {
  let $profile := access:get-current-person-profile()
  let $role-ref := access:get-function-ref-for-role($role)
  return 
    exists($profile//Role[FunctionRef = $role-ref]) and (count($profile//Role) eq 1)
};

(: ======================================================================
   Tests if current user has at least one role with the sight define 
   by the suffix (currently only 'omni')
   Note that sight is a funny way to define a role by what it is allowed to see
   ======================================================================
:)
declare function local:assert-sight( $suffix as xs:string ) as xs:boolean {
  let $groups-ref := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Sight eq $suffix]/Id/text()
  let $user-profile := access:get-current-person-profile()
  return
    $user-profile//FunctionRef = $groups-ref
};

(: ======================================================================
   Returns true if any of the token role definition from the rule
   yields for current user, groups, case, optional activity
   ======================================================================
:)
declare function access:assert-rule( $user as xs:string, $groups as xs:string*, $rule as xs:string, $project as element()?, $case as element()?, $activity as element()? ) as xs:boolean {
  some $token in tokenize($rule, " ")
    satisfies
      let $prefix := substring-before($token, ':')
      let $suffix := substring-after($token, ':')
      return
        (($prefix eq 'u') and ($user eq $suffix))
        or (($prefix eq 'g') and ($groups = $suffix))
        or (($prefix eq 'r') and access:assert-semantic-role($suffix, $project, $case, $activity))
        or (($prefix eq 's') and local:assert-sight($suffix))
        or false()
};

(: ======================================================================
   Tests a whitespace separated list of access tokens against current user
   Non contextual version (independent of case or activity) 
   Returns a boolean.
   ======================================================================
:)
declare function access:assert-access-rules( $rules as element()? ) as xs:boolean {
  let $user := oppidum:get-current-user()
  let $groups := oppidum:get-current-user-groups()
  return
    if ((('admin' = $user) or ('admin-system' = $groups)) and empty($rules/Meet[@Policy eq 'strict'])) then
      true() 
    else if ($rules/Avoid[@Policy eq 'only']) then (: exclusive rule - FIXME: limited to Avoid :)
      not(local:assert-current-exclusive-role(substring-after($rules/Avoid[@Policy eq 'only'], ':')))
    else
      (empty($rules/Meet) or (some $rule in $rules/Meet satisfies access:assert-rule($user, $groups, $rule/text(), (), (), ())))
      and
      (empty($rules/Avoid) or not(some $rule in $rules/Avoid satisfies access:assert-rule($user, $groups, $rule/text(), (), (), ())))
};

(: ======================================================================
   Tests a sequence of access rules against current user
   Contextual version dependent on case and/or activity
   Returns a boolean.
   FIXME: does not implement @Policy='only' 
   ======================================================================
:)
declare function access:assert-access-rules( $rules as element()?, $project as element()?, $case as element()?, $activity as element()? ) as xs:boolean {
  let $user := oppidum:get-current-user()
  let $groups := oppidum:get-current-user-groups()
  return
    if ((('admin' = $user) or ('admin-system' = $groups)) and empty($rules/Meet[@Policy eq 'strict'])) then 
      true() (: Administrators can do anything ! :)
    else
      (empty($rules/Meet) or (some $rule in $rules/Meet satisfies access:assert-rule($user, $groups, $rule/text(), $project, $case, $activity)))
      and
      (empty($rules/Avoid) or not(some $rule in $rules/Avoid satisfies access:assert-rule($user, $groups, $rule/text(), $project, $case, $activity)))
};

(: ======================================================================
   Tests access control model against a given action on a given case or activity for current user
   Returns a boolean
   ======================================================================
:)
declare function access:assert-user-role-for( $action as xs:string, $control as element()?, $project as element(), $case as element()?, $activity as element()? ) {
  let $rules := $control/Action[@Type eq $action]
  return
    if (empty($rules)) then
      if ($action = 'read') then (: enabled by default, mapping level should block non membres of users :)
        true()
      else (: any other action requires an explicit rule :)
        false()
    else
      access:assert-access-rules($rules, $project, $case, $activity)
};

(: ======================================================================
   Tests access control model against a given action on a given worklow actually in cur status
   Returns true if workflow status compatible with action, false otherwise
   See also workflow:gen-information in worklow/workflow.xqm
   ======================================================================
:)
declare function access:assert-workflow-state( $action as xs:string, $workflow as xs:string, $control as element(), $cur as xs:string ) as xs:boolean {
  let $rule :=
    if ($control/@TabRef) then (: main document on accordion tab :)
      fn:doc($globals:application-uri)//Workflow[@Id eq $workflow]/Documents/Document[@Tab eq string($control/@TabRef)]/Action[@Type eq $action]
    else (: satellite document in modal window :)
      let $host := fn:doc($globals:application-uri)//Workflow[@Id eq $workflow]//Host[@RootRef eq string($control/@Root)]
      return
        if ($host/Action[@Type eq $action]) then
          $host/Action[@Type eq $action]
        else
          $host/parent::Document/Action[@Type eq $action]
  return
    empty($rule)
      or $rule[$cur = tokenize(string(@AtStatus), " ")]
};

(: ======================================================================
   Tests if action on the document of given case or activity is allowed.
   The document is identified by its root element name.
   Returns true if allowed or false otherwise
   ======================================================================
:)
declare function access:check-user-can( $action as xs:string, $root as xs:string, $project as element(), $case as element()?, $activity as element()? ) as xs:boolean {
  let $control := fn:doc($globals:application-uri)/Application/Security/Documents/Document[@Root = $root]
  let $rules := $control/Action[@Type eq $action]
  return
    if (access:assert-user-role-for($action, $control, $project, $case, $activity)) then
      let $item := if ($activity) then $activity else if ($case) then $case else $project
      let $workflow := if ($activity) then 'Activity' else if ($case) then 'Case' else 'Project'
      return
        access:assert-workflow-state($action, $workflow, $control, $item/StatusHistory/CurrentStatusRef/text())
    else
      false()
};

declare function access:check-access-project ( $project as element() ) {
  (:  case visibility access control - :)
  let $user := oppidum:get-current-user()
  let $person := access:get-current-person-profile()/..
  let $omni-sight := access:check-omniscient-user($person/UserProfile)
  let $omni-project := $omni-sight or access:check-omniscient-project-user($person, $project)
  return
    $omni-project or access:check-user-can-open-project($person, $project)
};

(: ======================================================================
   Returns true if the current user can access a Case or false otherwise
   Applies same rules as in stage/search.xqm
   ======================================================================
:)
declare function access:check-access-case ( $case as element() ) {
  (:  case visibility access control - :)
  let $user := oppidum:get-current-user()
  let $person := access:get-current-person-profile()/..
  let $omni-sight := access:check-omniscient-user($person/UserProfile)
  let $omni-case := $omni-sight or access:check-omniscient-case-user($person, $case)
  return
    $omni-case or access:check-user-can-open-case($person, $case)
};


declare function access:pre-check-project(
  $project as element()?,
  $method as xs:string,
  $goal as xs:string?,
  $root as xs:string? ) as element()*
{
  if (empty($project)) then
    oppidum:throw-error('PROJECT-NOT-FOUND', ())
  else if (not(access:check-access-project($project))) then
    oppidum:throw-error("PROJECT-FORBIDDEN", $project/Information/Acronym/text())
  else if ($root) then 
    (: access to a specific case document :)
    if (access:check-user-can(if ($method eq 'GET') then 'read' else 'update', $root, $project, (), ())) then
      ()
    else
      oppidum:throw-error('FORBIDDEN', ())
  else if ($method eq 'GET') then
    (: access to case workflow view :)
    ()
  else
    oppidum:throw-error("URI-NOT-FOUND", ())
};

(: ======================================================================
   "All in one" utility function
   Checks case exists and checks user has rights to execute the goal action 
   with the given method on the given root document or has access to 
   the whole case if the root is undefined
   Either throws an error (and returns it) or returns the empty sequence
   ======================================================================
:)
declare function access:pre-check-case(
  $project as element()?,
  $case as element()?,
  $method as xs:string,
  $goal as xs:string?,
  $root as xs:string? ) as element()*
{
  if (empty($project)) then
    oppidum:throw-error('PROJECT-NOT-FOUND', ())
  else if (empty($case)) then
    oppidum:throw-error('CASE-NOT-FOUND', ())
  else if (not(access:check-access-project($project))) then
    oppidum:throw-error("PROJECT-FORBIDDEN", $project/Information/Acronym/text())
  else if (not(access:check-access-case($case))) then
    oppidum:throw-error("CASE-FORBIDDEN", $project/Information/Acronym/text())
  else if ($root) then 
    (: access to a specific case document :)
    if (access:check-user-can(if ($method eq 'GET') then 'read' else 'update', $root, $project, $case, ())) then
      ()
    else
      oppidum:throw-error('FORBIDDEN', ())
  else if ($method eq 'GET') then
    (: access to case workflow view :)
    ()
  else
    oppidum:throw-error("URI-NOT-FOUND", ())
};

(: ======================================================================
   "All in one" utility function
   Same as access:pre-check-case but at the activity level
   ======================================================================
:)
declare function access:pre-check-activity(
  $project as element()?,
  $case as element()?,
  $activity as element()?,
  $method as xs:string,
  $goal as xs:string?,
  $root as xs:string? ) as element()*
{
  if (empty($project)) then
    oppidum:throw-error('PROJECT-NOT-FOUND', ())
  else if (empty($case)) then
    oppidum:throw-error('CASE-NOT-FOUND', ())
  else if (empty($activity)) then 
    oppidum:throw-error('ACTIVITY-NOT-FOUND', ())
  else if (not(access:check-access-project($project))) then
    oppidum:throw-error("PROJECT-FORBIDDEN", $project/Information/Acronym/text())
  else if (not(access:check-access-case($case))) then
    oppidum:throw-error("CASE-FORBIDDEN", $project/Information/Acronym/text())
  else if ($root) then (: access to specific activity document :)
    let $action := if ($method eq 'GET') then 'read' else if ($goal eq 'delete') then $goal else 'update'
    let $control := fn:doc($globals:application-uri)/Application/Security/Documents/Document[@Root = $root]
    return
      if (access:assert-user-role-for($action, $control, $project, $case, $activity)) then
        if (access:assert-workflow-state($action, 'Activity', $control, string($activity/StatusHistory/CurrentStatusRef))) then
          ()
        else
          oppidum:throw-error('STATUS-DONT-ALLOW', ())
      else
        oppidum:throw-error('FORBIDDEN', ())

  else if ($method eq 'GET') then (: access to activity workflow view :)
    ()
  else
    oppidum:throw-error("URI-NOT-FOUND", ())
};

(: ======================================================================
   Returns the function reference corresponding to a role identified by its name
   Returns the empty sequence in case role unknown or empty input
   This is mainly to ease up code maintenance
   ======================================================================
:)
declare function access:get-function-ref-for-role( $roles as xs:string* ) as xs:string*  {
  if (exists($roles)) then
    fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role = $roles]/Id/text()
  else
    ()
};

(: ======================================================================
   Returns true() if the user profile can open any case and activity
   ======================================================================
:)
declare function access:check-omniscient-user( $profile as element()? ) as xs:boolean {
  some $function-ref in $profile//FunctionRef
  satisfies $function-ref = fn:doc($globals:global-information-uri)//Description[@Lang = 'en']/Functions/Function[@Sight = 'omni']/Id
};

declare function access:check-omniscient-project-user( $person as element()?, $project as element() ) as xs:boolean {
  if ($person) then 
    let $po := $project/Information/ProjectOfficerRef/text()
    let $ref := $person/Id/text()
    return
      exists($person//Role[(FunctionRef eq '12')])
      or (some $c in $project/Cases/Case satisfies access:check-omniscient-case-user( $person, $c ))
  else
    false()
};

(: ======================================================================
   Controls that user can open case workflow view
   NOTE: region-manager role reference (3) hard-coded (see also in global-information)
   ======================================================================
:)
declare function access:check-omniscient-case-user( $person as element()?, $case as element() ) as xs:boolean {
  if ($person) then 
    let $region := $case/ManagingEntity/RegionalEntityRef/text()
    let $nuts-code := fn:collection($globals:regions-uri)//Region[Id = $region]//Nuts/text()
    let $po := $case/../../Information/ProjectOfficerRef/text()
    let $ref := $person/Id/text()
    return
      ($region and ($person//Role[(FunctionRef eq '3') and (RegionalEntityRef = $region)]))
      or ($nuts-code and ($person//Role[(FunctionRef eq '14') and (Nuts/NutsRef = $nuts-code)]))
      or ($case/Management/AccountManagerRef and ($ref eq $case/Management/AccountManagerRef/text()))
      or ($person//Role[(FunctionRef eq '12')])
  else
    false()
};

declare function access:check-user-can-open-project( $person as element()?, $project as element() ) as xs:boolean {
  if ($person) then
    let $ref := $person/Id/text()
    let $region := $project/ManagingEntity/RegionalEntityRef/text()
    let $nuts-code := fn:collection($globals:regions-uri)//Region[Id = $region]//Nuts/text()
    return
      (
      ($region and ($person//Role[(FunctionRef eq '3') and (RegionalEntityRef = $region)]))
      or ($nuts-code and ($person//Role[(FunctionRef eq '14') and (Nuts/NutsRef = $nuts-code)]))
      or ($project/Cases/Case/Management/AccountManagerRef and ($ref = $project/Cases/Case/Management/AccountManagerRef/text()))
      or $ref and ($ref = $project/Cases/Case//Assignment/ResponsibleCoachRef/text()))
  else
    false()
};

declare function access:check-user-can-open-case( $person as element()?, $case as element() ) as xs:boolean {
  if ($person) then 
    let $ref := $person/Id/text()
    return
      ($ref and ($ref = $case//Assignment/ResponsibleCoachRef/text()))
  else
    false()
};

(: ======================================================================
   Returns true if current user is allowed to do some action on a given
   type of resource at full database level or false
   ======================================================================
:)
declare function access:check-omnipotent-user-for( $action as xs:string, $resource as xs:string ) as xs:boolean {
  let $security-model := fn:doc($globals:application-uri)/Application/Security/Resources/Resource[@Name = $resource]
  let $rules := $security-model/Action[@Type eq $action]
  return
    access:assert-access-rules($rules)
};

(: ======================================================================
   Implements one specific Assert element on Transition element from application.xml
   for item which may be a Case or an Activity
   Checks first current status compatibility with transition
   ====================================================================== 
:)
declare function access:assert-transition-partly( $item as element(), $assert as element()?, $subject as element()?) as xs:boolean {
  let $transition := $assert/parent::Transition
  return
    if ($transition and ($item/StatusHistory/CurrentStatusRef eq string($transition/@From))) then
      let $rules := $assert/true
      let $base := $subject
      return 
        if (count($rules) > 0) then
          every $expr in $rules satisfies util:eval($expr/text())
        else 
          false()
    else
      false()
};

(: ======================================================================
   Implements Assert element on Transition element from application.xml
   for item which may be a Case or an Activity
   Checks first current status compatibility with transition
   ====================================================================== 
:)
declare function access:assert-transition( $item as element(), $transition as element()?, $subject as element()?) as xs:boolean {
  if ($transition and ($item/StatusHistory/CurrentStatusRef eq string($transition/@From))) then
    let $rules := $transition/Assert/true
    let $base := $subject
    return 
      if (count($rules) > 0) then
        every $expr in $rules satisfies util:eval($expr/text())
      else 
        false()
  else
    false()
};

(: ======================================================================
   Asserts case data is compatible with transition
   This can be used to suggest transition to user or to prevent it
   ======================================================================
:)
declare function access:assert-transition( $case as element(), $from as xs:string, $to as xs:string, $subject as element()?) as xs:boolean {
  let $transition := fn:doc($globals:application-uri)//Workflow[@Id eq 'Case']//Transition[@From eq $from][@To eq $to]
  return access:assert-transition($case, $transition, $subject)
};

(: ======================================================================
   Asserts activity data is compatible with transition
   This can be used to suggest transition to user or to prevent it
   ======================================================================
:)
declare function access:assert-transition( $case as element(), $activity as element(), $from as xs:string, $to as xs:string, $subject as element()?) as xs:boolean {
  let $transition := fn:doc($globals:application-uri)//Workflow[@Id eq 'Activity']//Transition[@From eq $from][@To eq $to]
  return access:assert-transition($activity, $transition, $subject)
};

(: ======================================================================
   Implements Allow access control rules
   Currently limited to comma separated list of g:token
   See stats.xml @Allow or @ExcelAllow on Command element
   TODO: implement s:omni for users with sight omni
   ======================================================================
:)
declare function access:check-rule( $rule as xs:string? ) as xs:boolean {
  if (empty($rule) or ($rule eq '')) then
    true()
  else
    let $user := oppidum:get-current-user()
    let $groups := oppidum:get-current-user-groups()
    let $allowed := tokenize($rule,"\s*g:")[. ne '']
    return 
        if ($groups = $allowed) then
          true()
        else
          access:check-rules($user, $allowed)
};

(: ======================================================================
   FIXME: to be replaced with oppidum:get-current-user-groups after pi-cas release ! 
   ====================================================================== 
:)
declare function access:check-rules( $user as xs:string, $roles as xs:string* ) as xs:boolean {
  let $realm := oppidum:get-current-user-realm()
  return
  some $ref in fn:doc($globals:global-information-uri)//Description[@Lang eq 'en']/Functions/Function[@Role = $roles]/Id
  satisfies 
    if (empty($realm) or ($realm eq 'EXIST')) then 
      fn:collection($globals:persons-uri)//Person/UserProfile[Username eq $user]//FunctionRef = $ref
    else 
      fn:collection($globals:persons-uri)//Person/UserProfile[Remote[@Name eq $realm] eq $user]//FunctionRef = $ref
};

(: ======================================================================
   Rule to display command buttons in Statistics, give access to the underlying 
   functionality and display "Export excel csv" link in tables in export or print lists.
   Returns true() if allowed, false() otherwise.
   ======================================================================
:)
declare function access:check-stats-action( $page as xs:string, $action as xs:string, $link as xs:boolean ) as xs:boolean {
  let $command := fn:doc($globals:stats-uri)/Statistics/Filters/Filter[@Page = $page]/Formular/Command[@Action eq $action]
  return 
    if ($link) then
      access:check-rule(string($command/@ExcelAllow))
    else
      access:check-rule(string($command/@Allow))
};

(: ======================================================================
   Returns true() if the user's sight (i.e. cases and activities that s/he can see)
   is strictly limited to the role, false() otherwise (i.e. can see less or more)
   ====================================================================== 
:)
declare function access:check-sight( $user as xs:string, $role as xs:string ) as xs:boolean {
  let $realm := oppidum:get-current-user-realm()
  let $profile := 
    if (empty($realm) or ($realm eq 'EXIST')) then
      fn:collection($globals:persons-uri)//Person/UserProfile[Username eq $user]
    else
      fn:collection($globals:persons-uri)//Person/UserProfile[Remote[@Name eq $realm] eq $user]
  let $role-ref := fn:doc($globals:global-information-uri)//Description[@Lang eq 'en']/Functions/Function[@Role = $role]/Id
  return
    $profile//FunctionRef = $role-ref
    and not(access:check-omniscient-user($profile))
    and not($profile//FunctionRef = fn:doc($globals:global-information-uri)//Description[@Lang eq 'en']/Functions/Function[@Subsume = $role]/Id)
};
