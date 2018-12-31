xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Validation checks to be run against the database

   TODO
   - migrate as Schematron rules and use XML Prague 2015 article 

   February 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)
   
declare option exist:serialize "method=xml media-type=application/xhtml+xml";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace check = "http://oppidoc.com/ns/cctracker/check" at "../lib/check.xqm";


declare function local:count-multiple-projects ( $number as xs:integer) as xs:integer {
  let $CE := fn:collection('/db/sites/cctracker/cases')//ClientEnterprise
  let $all := for $i in $CE/@EnterpriseId return string($i)
  return
    count(
      for $i in $all
      return $all[index-of($all, $i)[$number]]
      ) div 2
};

declare function local:get-duplicated-project-ids ( $number as xs:integer ) {
  let $SET := fn:collection('/db/sites/cctracker/cases')//Case
  let $all := for $i in $SET//@ProjectId return string($i)
  return
    for $i in $all
    return $all[index-of($all, $i)[$number]]
};

let $nb-persons := count(fn:collection('/db/sites/cctracker/persons')//Person)
let $id-persons :=  
  count(distinct-values(fn:collection('/db/sites/cctracker/persons')//Person/Id))
  eq 
  $nb-persons
  
let $distinct-mail := distinct-values(fn:collection('/db/sites/cctracker/persons')//Person/Contacts/Email/text()[. ne ''])
let $nb-mail := count($distinct-mail)
let $shared-mail := 
  if (request:get-parameter-names() = 'full') then
    for $m in $distinct-mail
    where count(fn:collection('/db/sites/cctracker/persons')//Person[upper-case(Contacts/Email) eq upper-case($m)]) > 1 
    return $m
  else
    'use "full" parameter to see duplicates'
let $mail := $nb-mail eq $nb-persons
let $wrong-mail := 
  for $p in fn:collection('/db/sites/cctracker/persons')//Person
  where not(check:is-email($p/Contacts/Email/text()))
  return 
    concat($p/Name/FirstName, ' ', $p/Name/LastName, ' : "', $p/Contacts/Email, '"')

let $nb-enterprises := count(fn:doc('/db/sites/cctracker/enterprises/enterprises.xml')//Enterprise)
let $id-enterprises :=  
  count(distinct-values(fn:doc('/db/sites/cctracker/enterprises/enterprises.xml')//Enterprise/Id))
  eq 
  $nb-enterprises

let $nb-projects-id := count(distinct-values(fn:collection('/db/sites/cctracker/cases')//Case/@ProjectId))
let $nb-cases-imported := count(fn:collection('/db/sites/cctracker/cases')//Case[@ProjectId])
let $id-cases-imported :=  
  $nb-projects-id
  eq 
  $nb-cases-imported

let $nb-enterprises-imported := count(fn:collection('/db/sites/cctracker/cases')//ClientEnterprise[@EnterpriseId])
let $distinct-nb-enterprises-imported := count(distinct-values(fn:collection('/db/sites/cctracker/cases')//ClientEnterprise/@EnterpriseId))
let $id-enterprises-imported :=  
  $distinct-nb-enterprises-imported
  eq 
  $nb-enterprises-imported

let $nb-enterprises-with-2 := local:count-multiple-projects(2)

let $ok-projects := 
  if ($nb-cases-imported eq ($distinct-nb-enterprises-imported + $nb-enterprises-with-2)) then 
    concat(' = ', $distinct-nb-enterprises-imported - $nb-enterprises-with-2, ' (1 project) + ', $nb-enterprises-with-2 * 2, ' (2 projects)')
  else
    concat(' != ', $distinct-nb-enterprises-imported, ' + ', $nb-enterprises-with-2, ' != ', $nb-cases-imported, ' not ok')

return

  <div>
    <h1>Database report</h1>
    <h2>Stats</h2>
    <p>Total number of SME beneficiaries : { $distinct-nb-enterprises-imported } = { $distinct-nb-enterprises-imported - $nb-enterprises-with-2 } (1 project) + { $nb-enterprises-with-2 } (2 projects)</p>
    <p>Total number of cases : { $nb-cases-imported } { $ok-projects } </p>
    <p>Total number of projects ID : { $nb-projects-id } </p>
    <h2>Unicity check</h2>
    <p>Unicity of persons ID : { $id-persons } ({ $nb-persons })</p>
    <p>Unicity of enterprises ID : { $id-enterprises } ({ $nb-enterprises })</p>
    <p>Unicity of projects ID : { $id-cases-imported } ({ $nb-projects-id } / { $nb-cases-imported })</p>
    {
    <p style="color:red">Duplicated projects ID (only doublons, extend search manually if you want) : { local:get-duplicated-project-ids(2) }</p>
    }
    <h2>Email address check</h2>
    <p>Unicity of person email addresses : { $mail } ({ $nb-mail } out of { $nb-persons }) ({ string-join($shared-mail, ', ') })</p>
    <p>Misspelled email addresses ({count($wrong-mail)}) :</p>
    <ul>
     {
      for $m in $wrong-mail
      return <li>{ $m }</li>
     }
    </ul>
    { <span/> (:local:gen-multiples():) }
  </div>
