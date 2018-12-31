xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage contact persons for a Host

   December 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

(: ======================================================================
   Updates a user profile with a Role
   ======================================================================
:)
declare function local:add-role( $person as element(), $role-ref as xs:string, $other as element() ) as element()? {
  let $addition := <Role><FunctionRef>{ $role-ref }</FunctionRef>{ $other }</Role>
  let $profile := $person/UserProfile
  let $done := 
    if ($profile/Roles) then 
      update insert $addition into $profile/Roles
    else if ($profile) then
      update insert <Roles>{ $addition }</Roles> into $profile
    else
      update insert <UserProfile><Roles>{ $addition }</Roles></UserProfile> into $person
  return $done
};

(: ======================================================================
   Host contacts saving
   ====================================================================== 
:)
declare function local:save-contacts-for-host( $host-ref as xs:string, $submitted as element() ) as element()? 
{
  let $host := fn:collection($globals:hosts-uri)//Host[Id = $host-ref]
  let $contacts := if ($host/Contacts) then () else update insert <Contacts/> into $host
  return (
    for $contact in $host//Contact
    let $person := fn:collection($globals:persons-uri)//Person[Id/text() = $contact/PersonRef/text()]
    let $is-assigned := fn:collection($globals:persons-uri)//Person//Host[string(@For) = $host-ref][ContactRef/text() = $contact/PersonRef/text()]
    return
      if (not($submitted//Contact[PersonRef/text() = $contact/PersonRef/text()])) then
        if (count($is-assigned) eq 0) then
        (: remove assignment for every person no longer submitted if not assigned :)
          (
          update delete $contact,
          let $role-contact := $person/UserProfile/Roles/Role[FunctionRef eq '3']
          return 
            if ($role-contact) then update delete $role-contact else ()
          )
        else
          ajax:throw-error('CONTACT-STILL-ASSIGNED', ())
      else
        (),
     for $contact in distinct-values($submitted//Contact[PersonRef != ''][not(PersonRef = $host//PersonRef)])
     let $person := fn:collection($globals:persons-uri)//Person[Id/text() eq normalize-space($contact)]
     let $d := string(current-dateTime())
     let $func := access:get-function-ref-for-role('coach-contact')
     return
       (
         local:add-role($person, $func, <HostRef>{$host-ref}</HostRef>),
         update insert <Contact>{ element PersonRef { normalize-space($contact) }, element {'Date'} {$d} }</Contact> into $host/Contacts,
         ()
       )[last()]
    )
};

(: ======================================================================
   Host contacts reading
   ====================================================================== 
:)
declare function local:read-contacts-for-host( $host-ref as xs:string? ) as element()
{
  let $host := fn:collection($globals:hosts-uri)//Host[Id = $host-ref]
  return
    <Host>
      <Contacts>
      {
        for $contact in $host//Contact
        return
          <Contact>
          {
            $contact/PersonRef,
            misc:unreference($contact/Date)
          }
          </Contact>
      }
      </Contacts>
    </Host>
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $host-ref := tokenize($cmd/@trail, '/')[2]
return
  if (fn:collection($globals:global-info-uri)//Selector[@Name = "Hosts"]/Option[Id eq $host-ref]) then 
    (: acces control 1 :)
    let $user := oppidum:get-current-user()
    let $groups := oppidum:get-current-user-groups()
    let $profile := access:get-current-person-profile()
    return
      (: access control: check user is Host manager for host :)
      if ($profile//Role[FunctionRef eq '2'][HostRef eq $host-ref] or ($groups = ('admin-system'))) then 
        if ($m eq 'POST') then
          let $submitted := oppidum:get-data()
          return
           let $errors := local:save-contacts-for-host($host-ref, $submitted)
           return
             if (empty($errors)) then
               ajax:report-success('ACTION-UPDATE-SUCCESS', $host-ref, ())
             else
               ajax:report-validation-errors($errors)
        else (: assume GET :)
          local:read-contacts-for-host($host-ref)
      else
        oppidum:throw-error('FORBIDDEN', ())
  else 
    oppidum:throw-error('URI-NOT-FOUND', ())
