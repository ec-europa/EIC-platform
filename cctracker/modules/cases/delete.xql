xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to delete a Case. 

   March 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Checks that deleting $case is compatible with current DB state :
   - no Activity inside Case
   ======================================================================
:)
declare function local:validate-case-delete( $case as element() ) as element()* {
  let $found := for $activity in $case/Activities/Activity
                return $activity/Title/text()
  let $errors := if (not(empty($found))) then ajax:throw-error('CASE-CONTAINS-ACTIVITIES', string-join($found, ", ")) else ()
  return $errors
};

(: ======================================================================
   Deletes the case targeted by the request
   ======================================================================
:)
declare function local:delete-case( $case as element(), $redirect as xs:string ) as element()* {
  let $col-uri := util:collection-name($case)
  let $name := string($case/Title)
  return (
    xdb:remove($col-uri),
    ajax:report-success-redirect('DELETE-CASE-SUCCESS', $name, $redirect)
    )
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $case-no := string($cmd/resource/@name)
let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
(:let $lang := string($cmd/@lang):)
return
  if ($case) then (: sanity check :)
    if (access:check-case-delete($case)) then (: 1st check : authorized user ? :)
      let $errors := local:validate-case-delete($case)  (: 2nd: compatible database state ? :)
      return 
        if (empty($errors)) then 
          if ($m = 'DELETE' or (($m = 'POST') and (request:get-parameter('_delete', ()) eq "1"))) then (: real delete  :)
            local:delete-case($case, concat($cmd/@base-url, 'stage'))
          else if ($m = 'POST') then (: delete pre-step - we use POST to avoid forgery - :)
            ajax:report-success('DELETE-CASE-CONFIRM', $case/Title)
          else
            ajax:throw-error('URI-NOT-SUPPORTED', ())
        else
          $errors
    else
      ajax:throw-error('FORBIDDEN', ())
  else
    ajax:throw-error('URI-NOT-SUPPORTED', ())

