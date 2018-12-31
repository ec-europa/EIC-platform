xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to delete a Regional Entity. 

   January 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace search = "http://platinn.ch/coaching/search" at "search.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Removes Role element for a given role associated with a given region
   for every person in the list of references.
   DUPLICATE in region.xql
   ======================================================================
:)
declare function local:remove-team-for( $team-refs as xs:string*, $role as xs:string, $region-ref as xs:string ) {
  let $role-ref := access:get-function-ref-for-role($role)
  return
    for $ref in $team-refs
    let $role := fn:collection($globals:persons-uri)//Person[Id eq $ref]/UserProfile/Roles/Role[(FunctionRef eq $role-ref) and (RegionalEntityRef eq $region-ref)]
    where $role
    return
      update delete $role
};

(: ======================================================================
   Removes Role element for a every person in database with the role for the region
   ======================================================================
:)
declare function local:unlink-persons( $role as xs:string, $region-ref as xs:string ) {
  let $cur-refs := search:gen-linked-persons($role, $region-ref)/Id/text()
  return
    local:remove-team-for($cur-refs, $role, $region-ref)
};

(: ======================================================================
   Checks that deleting a Regional Entity is compatible with current DB state :
   - not linked to a Case (as ManagingEntity)
   TODO: 
   - do not delete but archive the Regional Entity so that it can be removed anyway
     (maybe this implies an unarchive command too ?)
   ======================================================================
:)
declare function local:validate-region-delete( $ref as xs:string ) as element()* {
  let $cases := for $p in fn:collection($globals:projects-uri)//Project[Case[.//ManagingEntity/RegionalEntityRef[. = $ref]]]
                return $p/Information/Title/text()
  return
    let $err1 := if (count($cases) > 0) then ajax:throw-error('REGION-LINKED-TO-CASE', string-join($cases, ", ")) else ()
    let $errors := ($err1)
    return
      if (count($errors) > 0) then
        let $explain :=
          string-join(
            for $e in $errors
            return $e/message/text(), ' ')
        return
          oppidum:throw-error('DELETE-REGION-FORBIDDEN', $explain)
      else
        ()
};

(: ======================================================================
   Delete the Regional Entity targeted by the request
   NOTE: currently if the last one is deleted, the next one that will be created 
   will get the same Id since we do not memorize a LastIndex
   ======================================================================
:)
declare function local:delete-region( $global as element(), $lang as xs:string ) as element()* {
  (: copy id and name to a new string to avoid loosing once deleted :)
  let $result := 
    <Response Status="success">
      <Payload Table="Region">
        <Value>{ string($global/Id) }</Value>
      </Payload>
    </Response>
  let $region := fn:collection($globals:regions-uri)//Region[Id = $global/Id/text()]
  let $name := string($global/Acronym)
  let $ref := string($global/Id)
  return (
    if ($region) then xmldb:remove(util:collection-name($region), concat($region/Id/text(), ".xml")) else (),
    local:unlink-persons('region-manager', $ref),
    local:unlink-persons('kam', $ref),
    ajax:report-success('DELETE-REGION-SUCCESS', $name, $result)
    )
};

(: ======================================================================
   Delete EEN Entity request handler
   ======================================================================
:)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $ref := tokenize($cmd/@trail,'/')[2]
let $item := fn:collection($globals:regions-uri)//Region[Id eq $ref]
let $lang := string($cmd/@lang)
return
  if ($item) then (: sanity check :)
    if (access:check-omnipotent-user-for('delete', 'Region')) then (: 1st check : authorized user ? :)
      let $errors := local:validate-region-delete($ref)  (: 2nd: compatible database state ? :)
      return 
        if (empty($errors)) then 
          if ($m = 'DELETE' or (($m = 'POST') and (request:get-parameter('_delete', ()) eq "1"))) then (: real delete  :)
            local:delete-region($item, $lang)
          else if ($m = 'POST') then (: delete pre-step - we use POST to avoid forgery - :)
            ajax:report-success('DELETE-REGION-CONFIRM', $item/Acronym/text())
          else
            ajax:throw-error('URI-NOT-SUPPORTED', ())
        else
          $errors
    else
      ajax:throw-error('FORBIDDEN', ())
  else
    ajax:throw-error('URI-NOT-SUPPORTED', ())
