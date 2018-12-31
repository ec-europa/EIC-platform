xquery version "1.0";
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

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace search = "http://oppidoc.com/ns/application/search" at "search.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare option exist:serialize "method=json media-type=application/json";

declare variable $local:vocabulary := ('accredit', 'reject', 'block');
declare variable $local:protected := ('reject', 'block');

(: ======================================================================
   Generates an in-memory cache to speed up page rendering by reducing
   the amount of database lookup operations
   FIXME: for 1 use cache entries could be tailored to fit 1 profile
   (see NOTE below)
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
   Returns a JSON "members" table row in case of success,
   throws an Oppidum error otherwise
   ======================================================================
:)
declare function local:gen-ajax-response( $res as element()?, $member as element() ) {
  let $profile := if ($member/PersonRef) then fn:collection($globals:persons-uri)//Person[Id eq $member/PersonRef]/UserProfile else ()
  return
    if (local-name($res) ne 'error') then
      <Response>
        <payload>
          <Action>update</Action>
          <Table>members</Table>
          {
          (: NOTE: maybe this is a little overkill to generate a cache just for 1 :) 
          search:gen-member-sample($member, $profile, local:gen-cache())
          }
        </payload>
      </Response>
    else
      $res
};

(: ======================================================================
   Implements accreditation controller POST request
   ======================================================================
:)
declare function local:do-accredit( $goal as xs:string, $member as element(), $person as element()? ) {
  if ($goal eq 'accredit') then (: applies 'accredit-delegate' template :)
    if ($member/Rejected or $person/UserProfile/Blocked) then
      oppidum:throw-error('CUSTOM', 'Delegate has already been blocked or rejected, you cannot accredit him or her')
    else
      local:gen-ajax-response(
        if (empty($person)) then
          template:do-create-resource('accredit-delegate', $member, (), <Form/>, ())
        else
          template:do-update-resource('accredit-delegate', (), $member, $person, <Form/>),
        $member
      )
  else (: applies 'block-delegate' or 'reject-delegate' template :)
    local:gen-ajax-response(
      template:do-update-resource(concat($goal, '-delegate'), (), $member, $person, <Form/>),
      $member
    )
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

(:*** ENTRY POINT - unmarshalling - access control - validation ***:)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $enterprise-id := tokenize($cmd/@trail, '/')[2]
let $member-id := tokenize($cmd/@trail, '/')[4]
let $current-userid := user:get-current-person-id()
let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $enterprise-id]
let $member := $enterprise//Member[Id eq $member-id]
let $person := local:get-matching-person-for($member)
let $submitted := oppidum:get-data()
let $goal := lower-case(local-name($submitted))
return
  if (($m = 'POST') and ($goal = $local:vocabulary) and exists($member)) then
    if ($current-userid eq $person/Id and $goal = $local:protected) then
      oppidum:throw-error('CUSTOM', concat('You cannot ', $goal, ' yourself'))
    else if (access:check-entity-permissions($goal, 'Member', $enterprise)) then
      local:do-accredit($goal, $member, $person)
    else
      oppidum:throw-error('FORBIDDEN', ())
  else
    oppidum:throw-error('URI-NOT-FOUND', ())
