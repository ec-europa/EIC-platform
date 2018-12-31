xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to delete a team Member

   May 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../modules/enterprises/enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Checks that deleting $member is compatible with current DB state
   FIXME: should send a WARNING (two-steps protocol) in case of LEAR deleting him/herself ?
   ======================================================================
:)
declare function local:validate-member-delete( $enterprise as element(), $id as xs:string, $member as element() ) as element()* {
  let $cie-ref := $member/ancestor::Enterprise/Id
  let $last-token := enterprise:get-last-scaleup-request($enterprise)
  return
    let $errors := (
      if (exists($member/PersonRef) and $last-token/TokenStatusRef eq '3' and $last-token/PersonKey eq $member/PersonRef) then
        oppidum:throw-error('WITHDRAW-TOKEN-FIRST', 'this user')
      else
        ()
      )
    return
      if (count($errors) > 0) then
        let $explain :=
          string-join(
            for $e in $errors
            return $e/message/text(), '. ')
        return
          oppidum:throw-error('DELETE-PERSON-FORBIDDEN', (concat($member/Information/Name/FirstName, ' ', $member/Information/Name/LastName), $explain))
      else
        ()
};

(: ======================================================================
   TODO: 
   - also delete Person if not Member in any Enterprise
   - also delete EnterpriseRef in Role in Person 
   - redirection on success
   ======================================================================
:)
declare function local:delete-member( $member as element(), $redirect as xs:string ) as element()* {
  (: copy name to a new string to avoid loosing once deleted :)
  let $name := concat($member/Information/Name/FirstName, ' ', $member/Information/Name/LastName)
  let $res := template:do-delete-resource('member', $member, custom:get-member-account($member))
  return
    if (local-name($res) ne 'error') then
      (: redirection => no need to ajax:concat-message with $res :)
      ajax:report-success-redirect('DELETE-MEMBER-SUCCESS', $name, $redirect)
    else
      $res
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $enterprise-no := tokenize($cmd/@trail, '/')[2]
let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $enterprise-no]
let $id := tokenize($cmd/@trail, '/')[4]
let $member := $enterprise//Members/Member[Id eq $id]
let $access := access:get-entity-permissions('delete', 'Member', $enterprise, $member)
return
  if ($m eq 'POST') then (: sanity check :)
    if (local-name($access) eq 'allow') then (: 1st check :)
      (: TODO: $profile extraction :)
      let $errors := local:validate-member-delete($enterprise, $id, $member)  (: 2nd check compatible database state :)
      return 
        if (empty($errors)) then 
          if ($m = 'DELETE' or (($m = 'POST') and (request:get-parameter('_delete', ()) eq "1"))) then (: real delete  :)
            local:delete-member($member, concat($cmd/@base-url, 'teams/', $enterprise-no))
          else if ($m = 'POST') then (: delete pre-step - we use POST to avoid forgery - :)
            ajax:report-success('DELETE-MEMBER-CONFIRM', concat($member/Information/Name/FirstName, ' ', $member/Information/Name/LastName))
          else
            ajax:throw-error('URI-NOT-SUPPORTED', ())
        else
          $errors
    else
      $access
  else
    ajax:throw-error('URI-NOT-SUPPORTED', ())

