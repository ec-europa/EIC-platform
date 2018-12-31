xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   POST Controller to <Request/>, <Allocate/> ScaleupEU token

   Notes:

   Implements Ajax JSON table protocol for "tokens" table rows (see also search.[xql, xqm] in teams)

   April 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace search = "http://oppidoc.com/ns/application/search" at "../teams/search.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:vocabulary := ('request', 'allocate', 'reject', 'withdraw');
declare variable $local:protected := ('allocate', 'reject', 'withdraw');

(: ======================================================================
   Generates an in-memory cache to speed up page rendering by reducing
   the amount of database lookup operations
   FIXME: for 1 use cache entries could be tailored to fit 1 profile
   TODO: factorize with accredit.xql in teams
   ======================================================================
:)
declare function local:gen-cache() as map() {
  map:put(
    display:gen-map-for('Functions', 'Brief', 'en'), (: FunctionsBrief :)
    'project-officers',
    custom:gen-project-officers-map()
  )
};

(: ======================================================================
   Returns a JSON "tokens" table row in case of success,
   throws an Oppidum error otherwise
   Switch HTTP response serialization to JSON
   TODO: extend protocol to support message (to popup in modal alert)
   ======================================================================
:)
declare function local:gen-ajax-response( $res as element()?, $member as element(), $profile as element() ) {
  util:declare-option("exist:serialize", "method=json media-type=application/json"),
  if (local-name($res) ne 'error') then
    <Response>
      <payload>
        <Action>update</Action>
        <Table>tokens</Table>
        {
        (: NOTE: maybe this is a little overkill to generate a cache just for 1 :)
        search:gen-token-sample($member, $profile, local:gen-cache())
        }
      </payload>
    </Response>
  else
    $res
};

declare function local:gen-ajax-responses( $res as element()?, $samples as element()+ ) {
  util:declare-option("exist:serialize", "method=json media-type=application/json"),
  if (local-name($res) ne 'error') then
    <Response>
      <payload>
        <Action>update</Action>
        <Table>tokens</Table>
        { $samples }
      </payload>
    </Response>
  else
    $res
};

(: ======================================================================
   Returns the Person that represents the member if it already exists in DB
   or the empty sequence. Matches by PersonRef then Email (EU login one).
   ======================================================================
:)
declare function local:get-matching-person-for ( $member as element()? ) as element()? {
  if (exists($member/PersonRef)) then
    globals:collection('persons-uri')//Person[Id eq $member/PersonRef]
  else if (exists($member)) then
    let $mail-key := normalize-space(lower-case($member/Information/Contacts/Email))
    return
      let $realm-name := 'ECAS' (: FIXME: single hard-coded at the moment - oppidum:get-current-user-realm():)
      return
        globals:collection('persons-uri')//Person[UserProfile/lower-case(Email[@Name eq $realm-name]) eq $mail-key]
  else
    ()
};

(: ======================================================================
   Return the name of the token owner from the company if not account-key
   or the empty sequence if no one
   ====================================================================== 
:)
declare function local:get-other-token-owner( $enterprise as element(), $account-key as xs:string ) as xs:string? {
  let $owner := globals:collection('persons-uri')//Person[.//Role[EnterpriseRef eq $enterprise/Id][FunctionRef eq '8']]
  (: TODO: test with $enterprise/TokenHistory ? :)
  return
    if ($owner and ($owner/Id ne $account-key)) then
      let $m := $enterprise/Team//Member[PersonRef eq $owner/Id]/Information/Name
      return concat($m/FirstName, ' ', $m/LastName)
    else
      ()
};

(: ======================================================================
   Return the last token request by the user if it matches the action
   or throws an error if the last token request does not match the action any more
   ====================================================================== 
:)
declare function local:get-last-token ( $enterprise as element(), $account-key as xs:string, $compat-status-ref as xs:string, $action as xs:string ) as element() {
  let $last := enterprise:get-most-recent-request($enterprise, $account-key)
  return 
    if ($last/TokenStatusRef eq $compat-status-ref) then
      $last
    else
      <error>{ display:gen-name-for("TokenStatus", $last/TokenStatusRef, "en") }</error>
      (:oppidum:throw-error("TOKEN-STATUS-MISMATCH", (display:gen-name-for("TokenStatus", $last/TokenStatusRef, "en"), $action)):)
};

(: ======================================================================
   Generate the last email for the MatchInvest protocol
   Usually this is the last token owner Email but if the last owner 
   has been suspended then this is the Email archived in token history
   ====================================================================== 
:)
declare function local:get-last-email ( $owner as element()?, $enterprise as element() ) as element()? {
  if (exists($owner)) then 
    $owner/UserProfile/Email[@Name eq 'ECAS']
  else
    let $last :=
      head(
        for $req in $enterprise//TokenHistory[@For eq 'ScaleupEU']/TokenRequest[TokenStatusRef eq '4']
        order by number($req/Order) descending
        return $req
      )
    return $last/Email
}; 

(: ======================================================================
   Implement ScaleupEU token allocation (and transfer) local effects
   FIXME: how to handle errors ?
   ====================================================================== 
:)
declare function local:do-allocate-imp ( $enterprise as element(), $owner as element()?, $new-owner as element(), $payload as element(), $pending as element()? ) 
{
  let $res := 
    (
    if (exists($owner)) then
      template:do-update-resource('remove-role', (), $owner, $enterprise, <FunctionRef>8</FunctionRef>)
    else
      (),
    template:do-update-resource('add-role', (), $new-owner, $enterprise, <FunctionRef>8</FunctionRef>),
    (: should be unique - transfer all just in case:)
    for $cur in $enterprise//TokenHistory[@For eq 'ScaleupEU']/TokenRequest[TokenStatusRef eq '3']
    return template:do-update-resource('token-transfer', (), $cur, (), <Form/>),
    if (exists($pending)) then
      template:do-update-resource('token-allocate', (), $pending, (), <Form>{ $payload/Contact/Email }</Form>)
    else
      template:do-create-resource('token', $enterprise, (),
                  <Form><TokenStatusRef>3</TokenStatusRef>{ $payload/Contact/Email }</Form>, $new-owner/Id)
    )
  return
    (: Test for some <error> result to at least print some feedback message :)
    ()
};

(: ======================================================================
   Implement ScaleupEU token allocation (and transfer) by first 
   creating / updating third-part MatchInvest service, then implementing 
   local effects upon success
   ====================================================================== 
:)
declare function local:do-allocate ( $enterprise as element(), $person as element(), $member as element(), $pending as element()? )
{
  let $owner := enterprise:get-token-owner-person-for($enterprise)
  let $payload := enterprise:gen-scaleup-update($enterprise, $member)
  return
    let $res := enterprise:get-match-invest-response(
                  services:post-to-service('invest', 'invest.end-point', $payload, "200"),
                  ()
                  )
    return
      if (local-name($res) ne 'error') then
        let $save := local:do-allocate-imp($enterprise, $owner, $person, $payload, $pending)
        let $cache := local:gen-cache()
        (: FIXME: extend JSON Table protocol to report partial error messages  :)
        return
          (: TODO: flatten $res using ajax:merge-messages(<success/>, $save) :)
          local:gen-ajax-responses(<success/>, 
            (
            if (exists($owner)) then (: transferred, include in data set to update table if it was displayed :)
              let $prev-member := $enterprise/Team//Member[PersonRef eq $owner/Id]
              return
                search:gen-token-sample($prev-member, $owner/UserProfile, $cache)
            else
              (),
            search:gen-token-sample($member, $person/UserProfile, $cache)
            )
            )
      else
        $res
};


(: ======================================================================
   Implement ScaleupEU token withdrawal local effects
   ====================================================================== 
:)
declare function local:do-withdraw-imp ( $enterprise as element(), $owner as element() ) 
{
  let $res := 
    (
    template:do-update-resource('remove-role', (), $owner, $enterprise, <FunctionRef>8</FunctionRef>),
    (: should be unique - transfer all just in case:)
    for $cur in $enterprise//TokenHistory[@For eq 'ScaleupEU']/TokenRequest[TokenStatusRef eq '3']
    let $email := $enterprise/Team//Member[PersonRef eq $cur/PersonKey]/Information/Contacts/Email
    return template:do-update-resource('token-withdraw', (), $cur, $email, <Form/>)
    )
  return
    (: Test for some <error> result to at least print some feedback message :)
    ()
};

(: ======================================================================
   Implement ScaleupEU token withdrawal by first querying third-part 
   MatchInvest service (suspend operation), then implementing local effects upon success
   ====================================================================== 
:)
declare function local:do-withdraw ( $enterprise as element(), $person as element(), $member as element(), $email-key as xs:string )
{
  (: invariant : $owner should be same as $person ! :)
  let $owner := enterprise:get-token-owner-person-for($enterprise)
  return 
    if ($owner/Id eq $person/Id) then
      let $payload := enterprise:gen-scaleup-suspend($enterprise, $member, $email-key)
      return
        let $res := enterprise:get-match-invest-response(
                      services:post-to-service('invest', 'invest.end-point', $payload, "200"),
                      ()
                      )
        return
          if (local-name($res) ne 'error') then
            let $res := local:do-withdraw-imp($enterprise, $owner)
            (: TODO: flatten $res to pass it to local:gen-ajax-response :)
            return
              local:gen-ajax-response(<success/>, $member, $person/UserProfile)
          else
            $res
    else
      oppidum:throw-error("CUSTOM", "Cannot withdraw token from non token owner")
};

(:*** ENTRY POINT - unmarshalling - access control - validation ***:)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $steps := tokenize($cmd/@trail, '/')
let $enterprise-id := $steps[2]
let $account-key := $steps[4]
let $current-userid := user:get-current-person-id()
let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $enterprise-id]
let $member := $enterprise//Member[PersonRef eq $account-key]
let $person := local:get-matching-person-for($member)
let $submitted := oppidum:get-data()
let $goal := lower-case(local-name($submitted))
return
  if (($m = 'POST') and ($goal = $local:vocabulary) and exists($member)) then
    (: TODO: access control ... if (access:check-entity-permissions($goal, 'Member', $enterprise)) then :)
    if ($goal eq 'request') then
      if (request:get-parameter('_confirmed', ()) eq '1') then
        let $res := template:do-create-resource('token', $enterprise, (),
                      <Form><TokenStatusRef>1</TokenStatusRef></Form>, $account-key)
        return
          if (local-name($res) eq 'success') then
            ajax:report-success-redirect('TOKEN-REQUEST-CONFIRMED', $enterprise/Information/Name, concat($cmd/@base-url, oppidum:get-current-user()))
          else
            $res
      else (: TODO: sanity check if user has already requested token :)
        let $other-owner := local:get-other-token-owner($enterprise, $account-key)
        return
          ajax:report-success(
            if (exists($other-owner)) then 'TOKEN-TAKEN-REQUEST-CONFIRM' else 'TOKEN-REQUEST-CONFIRM',
            $other-owner
            )
    else if ($goal = 'reject') then
      (: TODO: extend Ajax table protocol with Confirmation dialog :)
      let $last := local:get-last-token($enterprise, $account-key, '1', 'reject')
      return
        if (local-name($last) ne 'error') then
          (:if (request:get-parameter('_confirmed', ()) eq '1') then:)
          local:gen-ajax-response(template:do-update-resource('token-reject', (), $last, (), <Form/>), 
            $member, $person/UserProfile)
          (:else
            oppidum:throw-message("TOKEN-REJECT-CONFIRM", $person//Email[@Name eq 'ECAS']):)
        else
          oppidum:throw-error("TOKEN-STATUS-MISMATCH", ($last, 'reject'))
    else if ($goal = 'allocate') then
      (: TODO: extend Ajax table protocol with Confirmation dialog :)
      (: FIXME: check email has not been allocated a token in between in another team ? :)
      let $last-pending := local:get-last-token($enterprise, $account-key, '1', 'allocate')
      return
        if (local-name($last-pending) ne 'error') then (: allocate a pending one :)
          (:if (request:get-parameter('_confirmed', ()) eq '1') then:)
          local:do-allocate($enterprise, $person, $member, $last-pending)
          (:else
            oppidum:throw-message("TOKEN-REJECT-CONFIRM", $person//Email[@Name eq 'ECAS']):)
        else (: forced allocation of a non pending :)
          let $cur-tok-account := enterprise:get-token-owner-person-for($enterprise)
          return 
            if (exists($person)) then
              if (empty($cur-tok-account) or ($cur-tok-account/Id ne $person/Id)) then
                local:do-allocate($enterprise, $person, $member, ())
              else
                oppidum:throw-error("CUSTOM", "Token already allocated to that user")
            else
              oppidum:throw-error("CUSTOM", "You must accredit that user first  !")
    else if ($goal = 'withdraw') then
      (: TODO: extend Ajax table protocol with Confirmation dialog :)
      let $last := local:get-last-token($enterprise, $account-key, '3', 'withdraw')
      return
        if (local-name($last) ne 'error') then
          (:if (request:get-parameter('_confirmed', ()) eq '1') then:)
          local:do-withdraw($enterprise, $person, $member, $last/Email)
          (:else
            oppidum:throw-message("TOKEN-REJECT-CONFIRM", $person//Email[@Name eq 'ECAS']):)
        else
          oppidum:throw-error("TOKEN-STATUS-MISMATCH", ($last, 'withdraw'))
    else if ($goal = $local:protected) then
      oppidum:throw-error('CUSTOM', 'Not implemented yet !')
    else
      oppidum:throw-error('FORBIDDEN', ())
  else
    oppidum:throw-error('URI-NOT-FOUND', ())
