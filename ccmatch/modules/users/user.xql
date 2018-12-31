xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to create, import or update users

   Supports creation and importation by system administrator of permanent users
   or creation of users by self-registration

   Implements JSON Ajax protocol

   See also: read.xql

   October 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace system = "http://exist-db.org/xquery/system";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace session = "http://exist-db.org/xquery/session";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://oppidoc.com/ns/account" at "account.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Normalizes a string to compare it with another one
   TODO: handle accentuated characters (canonical form ?)
   ======================================================================
:)
declare function local:normalize( $str as xs:string* ) as xs:string* {
  for $s in $str
  return upper-case(normalize-space($s))
};

(: ======================================================================
   Checks submitted Person data is valid
   Returns a list of error messages or the empty sequence if no errors.
   ======================================================================
:)
declare function local:validate-person-submission( $data as element(), $curNo as xs:string? ) as element()* {
  let $key := local:normalize($data/Information/Contacts/Email/text())
  let $mail := fn:collection($globals:persons-uri)//Person[local:normalize(Information/Contacts/Email) = $key]
  let $ecas := fn:collection($globals:persons-uri)//Person[local:normalize(UserProfile/Remote[string(@Name) eq 'ECAS']) = $key]
  return
    if (exists($mail) and ((empty($curNo)) or not($curNo = $mail/Id))) then
      (: check user is overwritting another user's e-mail address :)
      ajax:throw-error('PERSON-EMAIL-CONFLICT', (display:gen-person-name($mail[Id ne $curNo][1], 'en'), $key))
    else if (exists($ecas) and ((empty($curNo)) or not($curNo = $ecas/Id))) then 
      (: check user is not overwritting another ECAS login e-mail key:)
      ajax:throw-error('PERSON-EMAIL-CONFLICT', (display:gen-person-name($ecas[Id ne $curNo][1], 'en'), $key))
    else 
      ()
};

(: ======================================================================
   Inserts a new Person inside the database
   Returns User row for management table
   NOTE: currently Id is computed, maybe that would be better to use a @LastId counter
   ======================================================================
:)
declare function local:create-person( $cmd as element(), $data as element(), $lang as xs:string, $person-ref as xs:string ) as element() {
  let $done := if ($person-ref eq 'users') then
                 let $roles := <UserProfile>
                                 <Remote Name="ECAS">
                                   {
                                   session:get-attribute('cas-user')/key/text()
                                   (: FIXME: force e-mail address to cas-user/key if self-registration :)
                                   }
                                  </Remote>
                                 <Roles><Role><FunctionRef>4</FunctionRef></Role></Roles>
                               </UserProfile>
                 return
                   system:as-user(account:get-secret-user(), account:get-secret-password(), person:create((), ($roles, $data/Information), ()))
               else
                 person:create((), $data/Information, ())
  return
    let $status := if ($person-ref eq 'users') then
                     (: assumes self-registration from /registration :)
                     let $reflexive := contains(request:get-header('Referer'), '/registration')
                     return
                       system:as-user(account:get-secret-user(), account:get-secret-password(), person:goto-next-status(fn:doc(string($done))/Person, $reflexive))
                   else
                     person:goto-next-status(fn:doc(string($done))/Person, false())
    return
      if (local-name($done) eq 'path') then (: success :)
        if ($person-ref eq 'users') then (: temporary profile creation :)
          ajax:report-success-redirect('ACTION-REGISTER-ACCOUNT-SUCCESS',
            lower-case(normalize-space($data/Information/Contacts/Email/text())), 
            concat($cmd/@base-url, fn:doc(string($done))/Person/Id))
        else (: permanent user update :)
          let $result :=  person:gen-user-sample-for-mgt-table(fn:doc(string($done))/Person, 'create')
          return ajax:report-success('ACTION-CREATE-SUCCESS', (), $result)
      else
        $done
};

(: ======================================================================
   Inserts a new Person with coach role inside the database
   Returns User row for import table
   FIXME: hard coded coach role code
   NOTE: currently Id is computed, maybe that would be better to use a @LastId counter
   ======================================================================
:)
declare function local:import-person( $cmd as element(), $data as element(), $lang as xs:string ) as element() {
  let $profile := 
        <UserProfile>
          <Remote Name="ECAS">{lower-case(normalize-space($data/Information/Contacts/Email/text()))}</Remote>
          <Roles><Role><FunctionRef>4</FunctionRef></Role></Roles>
        </UserProfile>
  let $done := person:create((), ($profile, $data/Information), ())
  return
    let $status := person:goto-next-status(fn:doc(string($done))/Person, false())
    return
      if (local-name($done) eq 'path') then (: success :)
        let $persists := request:get-parameter('persists', ())
        let $result := person:gen-import-sample-for-mgt-table(fn:doc(string($done))/Person, $persists)
        return ajax:report-success('ACTION-CREATE-SUCCESS', (), $result)
      else
        $done
};

(: ======================================================================
   Updates person's Information facet
   Mainly useful to update person's e-mail before creating login
   Returns Person model including the update flag (since the user must be allowed)
   ======================================================================
:)
declare function local:update-person( $person as element(), $data as element(), $lang as xs:string ) as element() {
  let $save := person:save-facet($person, $person/Information, $data/Information)
  return
    let $result := person:gen-update-sample-for-mgt-table($person)
    return ajax:report-success('ACTION-UPDATE-SUCCESS', (), $result)
};

(: Assumes POST at mapping level :)
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $person-ref := string($cmd/resource/@name)
let $data := oppidum:get-data()
(: command decoding :)
let $person := 
            if ($person-ref ne 'import') then (: permanent user update :)
              fn:collection($globals:persons-uri)//Person[Id eq $person-ref] 
            else
              ()
let $goal := if ($person-ref eq 'users') then 
               'create'
             else if ($person-ref ne 'import') then (: permanent user update :)
               'update'
             else
               'import'
return
  if (($goal = ('create', 'import')) or $person) then
    if (access:user-belongs-to('admin-system') or $person-ref eq 'users') then
      let $errors := local:validate-person-submission($data, $person/Id)
      return
        if (empty($errors)) then
          if ($goal = 'create') then
            local:create-person($cmd, $data, $lang, $person-ref)
          else if ($goal = 'import') then
            local:import-person($cmd, $data, $lang)
          else
            local:update-person($person, $data, $lang)
        else
          ajax:report-validation-errors($errors)
    else
      oppidum:throw-error('CUSTOM', $person-ref)
  else
    oppidum:throw-error("URI-NOT-FOUND", ())
