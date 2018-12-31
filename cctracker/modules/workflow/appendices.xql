xquery version "1.0";
(: ------------------------------------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Activity Appendices CRUD controller to upload or delete Appendices

   Manages the AXEL 'file' plugin Ajax protocol. Generates meta-data 
   which is stored inside an <Appendices> section inside the <Activity>

   September 2014 - (c) Copyright may be reserved
   ------------------------------------------------------------------ :)

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace annex = "http://www.oppidoc.com/ns/annex" at "../annexes/annex.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "workflow.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Generates Appendix meta-data for recording inside Activity 
   ======================================================================
:)
declare function local:gen-appendix-for-writing( $filename as xs:string, $activity as element() ) {
  let $uid := access:get-current-person-id ()
  return
    <Appendix>
      <Date>{ current-dateTime() }</Date>
      <SenderRef>{ $uid }</SenderRef>
      <ActivityStatusRef>{ $activity/StatusHistory/CurrentStatusRef/text() }</ActivityStatusRef>
      <File>{$filename}</File>
    </Appendix>
};

(: ======================================================================
   Uploads the request appendix file and its meta-data 
   FIXME: check user is allowed to upload !
   ======================================================================
:)
declare function local:upload-appendix( $cmd as element(), $activity as element() ) {
  let $lang := string($cmd/@lang)
  let $res := annex:submit-file($cmd)
  return
    if (local-name($res) eq 'success') then (: rewrites response to inlude meta-data :)
      (
      response:set-status-code(201), (: FIXME: oppidum throw-message should do that ? :)
      let $item := local:gen-appendix-for-writing($res/message, $activity)
      return
        (
        if ($activity/Appendices) then
          update insert $item into $activity/Appendices
        else
          update insert <Appendices>{ $item }</Appendices> into $activity,
          <success>
            {
            $res/message,
            <payload>
              {
              workflow:gen-annexe-for-viewing ($lang, $item, $res/message, $activity/No, (), true())
              }
            </payload>
            }
           </success>
        )
      )
    else
      $res
};

(: ======================================================================
   Deletes the requested Appendix file and its meta-data 
   ======================================================================
:)
declare function local:delete-appendix( $cmd as element(), $activity as element() ) {
  let $filename := concat($cmd/resource/@name, '.', $cmd/@format)
  let $item := $activity//Appendix[File eq $filename]
  return 
    if (access:check-appendix-delete($item)) then
      let $res := annex:delete-file($cmd, $filename)
      return
        if ($item and (local-name($res) eq 'success')) then (: removes meta-data :)
          (
          update delete $item,
          $res
          )
        else
          $res
    else
      oppidum:throw-error("FORBIDDEN", ())
};

(: ======================================================================
   Returns target Activity or empty sequence
   ======================================================================
:)

declare function local:get-activity( $cmd as element() ) as element()? {
  let $tokens := tokenize($cmd/@trail, '/')
  let $case-no := $tokens[2]
  let $activity-no := $tokens[4]
  let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
  return $case/Activities/Activity[No = $activity-no]
};

(:::::::::::::  BODY  ::::::::::::::)

let $cmd := oppidum:get-command()
let $m := request:get-method()
return
  if ($m = 'POST') then
    if (request:get-parameter('xt-file-preflight', ())) then (: preflight before file upload :)
      annex:submit-preflight($cmd)  
    else (: either upload / delete an appendix into / from an activity :)
      let $activity := local:get-activity($cmd)
      return
        if ($activity) then
          if (request:get-parameter('_delete', ()) eq "1") then (: delete :)
            local:delete-appendix($cmd, $activity)
          else  (: assumes file upload after preflight :)
            local:upload-appendix($cmd, $activity)
        else
          oppidum:throw-error("URI-NOT-FOUND", ())
  else
    oppidum:throw-error("URI-NOT-FOUND", ())
