xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to :
   - save feedback responses
   - read feedback responses (authorized users only !)

   Returns Ajax error or redirect to the done page !

   TODO: factorize "investors" category

   October 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../../xcm/modules/users/account.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../../xcm/lib/database.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Creates feedback document to save in database
   FIXME: - add EventKey to link to event meta-data
   ====================================================================== 
:)
declare function local:expand-data( $event-def as element(), $form as element() ) as element() {
  <Feedback>
    <Category>investor</Category>
    <EventKey>{ $event-def/Id/text() }</EventKey>
    <EventBucket>{  tokenize(util:collection-name($event-def), '/')[last()] }</EventBucket>
    <Answers>
      { $form/* }
    </Answers>
  </Feedback>
};

(: ======================================================================
   Saves an anonymouys feedback form in the corresponding event
   ======================================================================
:)
declare function local:handle-post ( $event-def as element() ) {
  let $form := oppidum:get-data()
  let $validation := template:do-validate-resource("investor-event-feedback", (), (), $form)
  return
    if (local-name($validation) ne 'valid') then
      $validation
    else
      let $res := system:as-user(account:get-secret-user(), account:get-secret-password(),
                    template:do-create-resource("investor-event-feedback", (), (), local:expand-data($event-def, $form), ()))
      return
        if (local-name($res) ne 'error') then
          ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), 'investors/done')
        else
          $res
};

(: ======================================================================
   Returns answers for the submission matching a submission key
   (currently the submission No but this could be replaced by another scheme)
   ====================================================================== 
:)
declare function local:read-submission ( $event-no as xs:string, $submission-no as xs:string ) {
  (: FIXME: replace trick with EventKey in Feedback, but this requires to migrate legacy submissions :)
  (: trick because feedback entity uses mirror of event entity sharding as per database.xml :)
  let $index := number($submission-no)
  let $mirror := database:gen-collection-for-key ('', 'event', $event-no) 
  let $resource-uri := concat($globals:feedbacks-uri, '/', $mirror, '/', $event-no, '.xml')
  let $feedback := fn:doc($resource-uri)//Feedback[position() eq $index]
  return
    if (exists($feedback)) then
      <Feedback>
        <EditHistory>
          <CreationDate>{ display:gen-display-date-time($feedback/@Creation) }</CreationDate>
        </EditHistory>
        { $feedback/Answers/* }
      </Feedback>
    else
      <Feedback/>
};

(: MAIN ENTRY POINT :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $target := $cmd/resource/@name
let $tokens := tokenize($cmd/@trail, '/')
let $event-id := $tokens[3]
let $category := $tokens[4]
return
  let $event-def := fn:collection($globals:events-uri)//Event[Id eq $event-id]
  return
    if ($event-def) then 
      if ($m eq 'POST' and $target eq 'investors') then 
        (: e.g. POST /feedbacks/events/14/investors :) 
        local:handle-post($event-def)
      else if ($m eq 'GET' and $cmd/@format eq 'data' and matches($target, '\d+')) then 
        (: e.g. /feedbacks/events/14/investors/1.data :)
        let $access := access:get-entity-permissions('export', 'Feedbacks', <Unused/>, $event-def)
        return
          if (local-name($access) eq 'allow') then
            local:read-submission($event-id, $target)
          else
            $access
      else
        oppidum:throw-error("URI-NOT-SUPPORTED", ())
    else
      oppidum:throw-error("URI-NOT-SUPPORTED", ())
    
