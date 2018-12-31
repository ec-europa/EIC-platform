xquery version "1.0";
(: ------------------------------------------------------------------
   Cockpit - EIC SME Dashboard Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Validation checks to be run against the database

   TODO
   - migrate as Schematron rules and use XML Prague 2015 article 

   June 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)
   
declare option exist:serialize "method=xml media-type=application/xhtml+xml";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../app/custom.xqm";

declare variable $local:persons := globals:collection('persons-uri');
declare variable $local:enterprises := globals:collection('enterprises-uri');

declare function local:gen-missing-enterprise-ref() as xs:string* {
  $local:persons/Person[descendant::Role[FunctionRef = ('3', '4') and empty(EnterpriseRef)]]/Id
};

(: ======================================================================
   Returns list of account refs who are not member in any enterprise
   (no PersonRef)
   ====================================================================== 
:)
declare function local:gen-missing-person-ref() as xs:string* {
(: SLOW -
  for $ref in $local:persons//EnterpriseRef
  let $id := $ref/ancestor::Person/Id
  where empty($local:enterprises//Enterprise[Id eq $ref]//Member[PersonRef eq $id ])
  return
    concat($id, ':', $ref):)
  let $person-refs := distinct-values($local:enterprises//Member/PersonRef)
  let $account-ids := $local:persons/Person/Id
  return
    $account-ids[empty(index-of($person-refs, .))] 
};

declare function local:gen-wrong-enterprise-ref( $role-ref ) as xs:string* {
  for $role in $local:persons/Person//Role[FunctionRef eq $role-ref]
  let $not-found := 
    for $ref in $role/EnterpriseRef
    (:slow - where empty($local:enterprises/Enterprise[Id eq .]):)
    where string-length($ref) > 4
    return $ref
  return 
    if ($not-found) then
      concat(
        custom:gen-person-name($role/ancestor::Person/Id, 'en'), 
        ' (', $role/ancestor::Person/Id, '[', string-join($not-found, ', ') ,'])'
        )
    else
      ()
};

declare function local:gen-multi-enterprise-ref( $role-ref ) as xs:string* {
  for $role in $local:persons/Person//Role[FunctionRef eq $role-ref]
  let $count := count($role/EnterpriseRef)
  where $count > 1
  return 
    concat(
      custom:gen-person-name($role/ancestor::Person/Id, 'en'), 
      ' (', $role/ancestor::Person/Id, '[', $count ,'])'
      )
};

let $nb-enterprises := count(globals:collection('enterprises-uri')//Enterprise)
let $nb-person := count(globals:collection('persons-uri')//Person)
let $nb-lear := count(globals:collection('persons-uri')//Person[.//Role[FunctionRef eq '3']])
let $nb-lear-not-delegate := count(globals:collection('persons-uri')//Person[.//Role[FunctionRef eq '3'] and not(.//Role[FunctionRef eq '4'])])
let $nb-delegate-not-lear := count(globals:collection('persons-uri')//Person[.//Role[FunctionRef eq '4'] and not(.//Role[FunctionRef eq '3'])])
let $nb-delegate := count(globals:collection('persons-uri')//Person[.//Role[FunctionRef eq '4']])
let $nb-lear-delegate := count(globals:collection('persons-uri')//Person[(.//Role/FunctionRef eq '3') and (.//Role/FunctionRef eq '4')])
return
  <div>
    <h1>Database report</h1>
    <h2>Stats</h2>
    <p>Total number of Person : { $nb-person }</p>
    <p>Total number of LEAR : { $nb-lear }</p>
    <p>Total number of LEAR and Delegate : { $nb-lear-delegate }</p>
    <p>Total number of LEAR and not Delegate : { $nb-lear-not-delegate }</p>
    <p>Total number of Delegates : { $nb-delegate }</p>
    <p>Total number of Delegate and not LEAR : { $nb-delegate-not-lear }</p>
    <p>Total of LEAR and not Delegate + Delegate and not LEAR + LEAR and Delegate : { $nb-lear-not-delegate + $nb-delegate-not-lear + $nb-lear-delegate }</p>
    <p>Difference with total : { $nb-person - ($nb-lear-not-delegate + $nb-delegate-not-lear + $nb-lear-delegate) }</p>
    <hr/>
    <p>Total number of enterprises : { $nb-enterprises }</p>
    <p>Total number of projects ID : TBD </p>
    <h2>Existence check</h2>
    <p>Total number of Delegate with more than a one EnterpriseRef : 
      {
      let $found := local:gen-multi-enterprise-ref('4')
      return 
        concat(' ', count($found), '  ', string-join($found, ' / ')
          )
      }  
    </p>
    <p>Total number of Delegate with bad EnterpriseRef :
      {
      let $missing := local:gen-wrong-enterprise-ref('4')
      return 
        concat(' ', count($missing), ' : ', string-join($missing, ' / ')
          )
      }  
    </p>
    <p>Total number of LEAR with more than a one EnterpriseRef :
      {
      let $found := local:gen-multi-enterprise-ref('3')
      return 
        concat(' ', count($found), ' : ', string-join($found, ' / ')
          )
      }  
    </p>    
    <p>Total number of LEAR with bad EnterpriseRef :
      {
      let $missing := local:gen-wrong-enterprise-ref('3')
      return 
        concat(' ', count($missing), ' : ', string-join($missing, ' / ')
          )
      }  
    </p>
    <h2>Unicity check</h2>
    <p>Total number of @EnterpriseId distinct values : { count(distinct-values(globals:collection('enterprises-uri')//Enterprise/@EnterpriseId)) }</p>
    <p>Total number of Enterprise with @EnterpriseId : { count(globals:collection('enterprises-uri')//Enterprise[@EnterpriseId]) }</p>
    <p>Total number of @MasterId distinct values : { count(distinct-values(globals:collection('enterprises-uri')//Enterprise/@MasterId)) }</p>
    <p>Total number of Enterprise with @MasterId : { count(globals:collection('enterprises-uri')//Enterprise[@MasterId]) }</p>
    <h2>Consistency check</h2>
    <p>Total number of Accounts (Person) of LEAR or Delegate with missing ref to Enterprise : 
    {
    let $found := local:gen-missing-enterprise-ref()
    return 
      concat(' ', count($found), ' : ', string-join($found, ' / ')
        )
    }  
    </p>
    <p>Total number of Accounts (Person) of LEAR or Delegate with missing membership in Enterprise : 
    {
    let $found := local:gen-missing-person-ref()
    return 
      concat(' ', count($found), ' : ', string-join($found, ' / ')
        )
    }  
    </p>    
  </div>
