xquery version "3.0";
(: ------------------------------------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors: Franck Leplé <franck.leple@amplexor.com>

   Admission's library

   November 2018 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace admission = "http://oppidoc.com/ns/application/admission";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace search = "http://oppidoc.com/ns/application/search" at "../teams/search.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Generates an in-memory cache to speed up page rendering by reducing
   the amount of database lookup operations
   FIXME: for 1 use cache entries could be tailored to fit 1 profile
   (see NOTE below)
   ======================================================================
:)
declare function admission:gen-cache() as map() {
  map:put(
    display:gen-map-for('Functions', 'Brief', 'en'), (: FunctionsBrief :)
    'project-officers',
    custom:gen-project-officers-map()
  )
};

(: ======================================================================
   Returns a JSON "members" table row in case of success,
   throws an Oppidum error otherwise
   ======================================================================
:)
declare function admission:gen-ajax-response( $res as element()?, $person as element() ,$admission as element(), $type as xs:string ) {
  let $profile := $person/UserProfile
  return
    if (local-name($res) ne 'error') then
      <Response>
        <payload>
          <Action>update</Action>
          <Table>{ $type }</Table>
          {
          (: NOTE: maybe this is a little overkill to generate a cache just for 1 :) 
            if ($type eq 'investors') then
              search:gen-pending-investor-sample ( $person, $admission, admission:gen-cache() )
            else
              search:gen-pending-user-sample ( $person, $admission)
          }
        </payload>
      </Response>
    else
      $res
};

(: ======================================================================
   Add member to existing enterprises from the user auto registration form
   Update user account (Person collection - adding Role) and Admission status
   Parameters:
   - $admission : the admission form
   - $person : The account create when the form was submitted
   Return <success/> or <error>string</error>
   ======================================================================
:)
declare function admission:add-new-member-to-enterprise($person as element(), $admission as element()) {
  if (exists($admission/OrganisationList//EnterpriseRef)) then
    for $entrRef in $admission/OrganisationList//EnterpriseRef
    return
      let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id/text() eq $entrRef/text()]
      (: check user joining a company is not already a member and if so simply update his member profile
         first check implies the user have been accredited from another path after the admission submission
         second check implies the user was also pending user in the company (e.g. added by account owner)
         :)
      let $resEnterprise :=
        if ($enterprise/Team/Members/Member[PersonRef/text() eq $person/Id/text()]
            or $enterprise/Team/Members/Member/Information/Contacts[lower-case(Email) eq $admission/ParticipantInformation/lower-case(Email)]
            ) then
          template:do-update-resource('generic-team-member', $person/Id, $enterprise, $person, $admission)
        else
          template:do-create-resource('generic-team-member', $enterprise, $person, $admission, ())

      let $resAccount := if (local-name($resEnterprise) eq 'success') then 
                           template:do-update-resource('user-account-join-legacy-company', $person/Id, $enterprise, $person, $admission) 
                         else 
                           <error>{ concat("Company ", $entrRef, " adding member failed") }</error>
      let $resAdmission :=  if (local-name($resAccount) eq 'success') then 
                              template:do-update-resource('admission-accredit-company', (), $enterprise, $admission, <form>1</form>)
                            else 
                              <error>{ concat("Person ", $person/Id, " update account failed") }</error>
       return              
         if (local-name($resAdmission) eq 'success') then  
            $resAdmission
         else
           <error>{ concat("User ", $person/Id, " adding role to company ", $entrRef , " failed") }</error>
  else 
  if (exists($admission/isECUser[text() eq 'yes'])) then (:case of member to assign to European Institution company:)
    let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Settings/Teams eq 'EC'] (:[Information/Name ='European Institution']:)
      (: check user joining a company is not already a member and if so simply update his member profile
         first check implies the user have been accredited from another path after the admission submission
         second check implies the user was also pending user in the company (e.g. added by account owner)
         :)
      let $resEnterprise :=
        if ($enterprise/Team/Members/Member[PersonRef/text() eq $person/Id/text()]
            or $enterprise/Team/Members/Member/Information/Contacts[lower-case(Email) eq $admission/ParticipantInformation/lower-case(Email)]
            ) then
          template:do-update-resource('generic-team-member', $person/Id, $enterprise, $person, $admission)
        else
          template:do-create-resource('generic-team-member', $enterprise, $person, $admission, ())

      let $resAccount := if (local-name($resEnterprise) eq 'success') then 
                           template:do-update-resource('user-account-join-legacy-company', $person/Id, $enterprise, $person, $admission) 
                         else 
                           <error>{ concat("Company ", $enterprise/Id/text(), " adding member failed") }</error>
       return              
         if (local-name($resAccount) eq 'success') then  
            $resAccount
         else
           <error>{ concat("User ", $person/Id, " adding role to company ",  $enterprise/Id/text() , " failed") }</error>
  else
  (: pass though :)
    <success/>
};

(: ======================================================================
   Remove pending user role from user account
   Return <success/> or <error>string</error>
   ======================================================================
:)
declare function admission:remove-pending-role-in-enterprise($person as element(), $admission as element()) {
  let $res :=  template:do-update-resource('self-user-account-delete-pending-role', $person/Id, $person, (), $admission)
  return
    if (local-name($res) eq 'success') then
      $res
    else
      <error>User { $person/Id/text() } accreditation failed  during pending role suppression</error>
};
