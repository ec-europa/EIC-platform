xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Write executive summary to coach CurriculumVitae

   DEPRECATED: not used any more since executive summary managed as a facet 
   within competences

   October 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $submitted as element() ) as element()* {
  let $length := string-length(normalize-space($submitted/Summary))
  return
    if ($length > 500) then
      let $fat := $length - 500
      return
        oppidum:throw-error('CUSTOM', concat('Your executive summary contains ', $length, ' characters; you must remove at least ', $fat, ' characters to remain below 500 characters'))
    else if ($length < 1) then
      oppidum:throw-error('CUSTOM', 'Your executive summary cannot be empty')
    else
      ()
};

declare function local:update-summary( $person as element() ) {
  let $submitted := oppidum:get-data()
  let $errors := local:validate-submission($submitted)
  return
    if (empty($errors)) then (: validation :)
      let $data := <CurriculumVitae>{ $submitted/Summary }</CurriculumVitae>
      let $payload := <p id="cm-coach-cv-summary">{ normalize-space($submitted/Summary) }</p>
      return
        (
        person:save-facet($person, $person/CurriculumVitae, $data),
        ajax:report-success('ACTION-UPDATE-SUCCESS', (), $payload)
        )
    else
      $errors
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
(: acces control 1 :)
let $user := oppidum:get-current-user()
let $token := tokenize($cmd/@trail, '/')[1]
let $groups := oppidum:get-current-user-groups()
let $person := access:get-person($token, $user, $groups)
return
  if (local-name($person) ne 'error') then
    if ($m eq 'POST') then
      if ($token eq $user) then (: access control 2 :)
        util:exclusive-lock($person, local:update-summary($person))
      else
        oppidum:throw-error('FORBIDDEN', ())
    else
      oppidum:throw-error('NOT-FOUND', ())
  else
    $person
