xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to delete an Annexe

   LIMITATION : 
   - limited to annexes of Case because of the way the Case base collection is computed

   March 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Delete the annexe targeted by the request
   ======================================================================
:)
declare function local:delete-annexe( $col-uri as xs:string, $name as xs:string) as element()* {
  let $exec :=  xdb:remove($col-uri, $name)
  return
    ajax:report-success('DELETE-ANNEXE-SUCCESS', $name)
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $tokens := tokenize($cmd/@trail, '/')
let $case-no := $tokens[2]
let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
return
  if ($case and ($m = 'POST') and (request:get-parameter('_delete', ()) eq "1")) then (:($m = 'DELETE'):)
    (: $case and $activity needed for access control :)
    let $col-uri := util:collection-name($case)
    let $activity-no := $tokens[4]
    let $activity := $case/Activities/Activity[No = $activity-no]
    let $file-uri := concat($col-uri, '/', $cmd/resource/@resource, '/', $cmd/resource/@name, '.', $cmd/@format)
    return
      if (util:binary-doc-available($file-uri)) then
        if (access:check-annexe-upload-or-delete($case, $activity)) then (: 1st check : authorized user ? :)
          local:delete-annexe(concat($col-uri, '/', $cmd/resource/@resource), concat($cmd/resource/@name, '.', $cmd/@format))
        else
          ajax:throw-error('FORBIDDEN', ())
      else
        ajax:throw-error('URI-NOT-SUPPORTED', ())
  else
    ajax:throw-error('URI-NOT-SUPPORTED', ())
