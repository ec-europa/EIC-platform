xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>

   Display a page with a list of links to external feedbacks 
   received for the target event (actually only investors feedback)

   TODO: take Category into account to group by Category

   November 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../modules/enterprises/enterprise.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../../xcm/lib/database.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := oppidum:get-command()
let $event-no := $cmd/resource/@name
(: FIXME: replace trick with EventKey in Feedback, but this requires to migrate legacy submissions :)
(: trick because feedback entity uses mirror of event entity sharding as per database.xml :)
let $mirror := if (matches($event-no, '\d+')) then database:gen-collection-for-key ('', 'event', $event-no) else '-1'
let $resource-uri := concat($globals:feedbacks-uri, '/', $mirror, '/', $event-no, '.xml')
let $event-def := fn:collection($globals:events-uri)//Event[Id eq $event-no]
return
  let $access := access:get-entity-permissions('export', 'Feedbacks', <Unused/>, $event-def)
  return
    if (local-name($access) eq 'allow') then
      <Page StartLevel="1" skin="fonts extensions">
        <Window>Events feedbacks</Window>
        <Model>
          <Navigation>
            <Mode>dashboard</Mode>
            <Name>Events feedbacks</Name>
          </Navigation>
        </Model>
        <Content>
          <Title Level="1" style="margin-top: 0;margin-bottom:0">Feedbacks for { custom:gen-event-name($event-def) }</Title>
          <Feedbacks Src="{ $resource-uri }">
          {
          for $feedback at $i in fn:doc($resource-uri)//Feedback
          let $category := string($feedback/Category)
          return
            <Feedback>
              <Date>{ display:gen-display-date-time($feedback/@Creation) }</Date>
              { $feedback/Answers/Contact/Company }
              <Link>{ string($event-no) }/investors/{ $i }</Link>
            </Feedback>
          }
          </Feedbacks>
        </Content>
      </Page>
    else
      $access
  
  

    
