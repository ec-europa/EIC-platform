xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Controller to duplicate an event from submitted (POST) event meta data
 
   November 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Manually configured function to reinitialize or copy elements 
   from a sample Event definition to create a new one
   ====================================================================== 
:)
declare function local:bootstrap-iter( $cur as element()* ) as element()* {
  for $c in $cur 
  return
    if ($c) then
      element { local-name($c) } { 
        for $a in $c/@*[local-name() ne 'File']
        return $a,
        typeswitch($c)
          case element(Template) return $c/text()
          case element(Programme) return $c/text()
          case element(PublicationStateRef) return '1'
          default return local:bootstrap-iter($c/*[local-name(.) ne 'Resources'])
        }
    else 
      ()
};

(: ======================================================================
   Return data to bootstrap an event from the content of another event

   Keep Template, @WorkflowId and Programme
   Set PublicationStateRef to "Draft"
   Filter out (Remove)Resources and @File
   and set all other fields to empy content
   ====================================================================== 
:)
declare function local:bootstrap-event( $submitted as element() ) as element() {
  local:bootstrap-iter(
    <Event>
      <PublicationStateRef/>
      { $submitted/*[not(local-name() = ('Id', 'PublicationStateRef'))] }
    </Event>
    )
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $submitted := oppidum:get-data()
return
  if ($m = 'POST') then
    let $event-def := fn:collection($globals:events-uri)//Event[Id eq $submitted/Id]
    return  
      if ($event-def) then
        if (access:check-entity-permissions('manage', 'Events')) then
          let $res := template:do-create-resource('event', $event-def, (), local:bootstrap-event($submitted), ())
          return
            if (local-name($res) eq 'success') then (: reload page on success :)
              ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), 'management')
            else
              $res
        else
          oppidum:throw-error('NOT-FOUND', ())
      else
        oppidum:throw-error('FORBIDDEN', ())
  else
    oppidum:throw-error('URI-NOT-SUPPORTED', ())
