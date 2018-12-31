xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Individualized landing page for users or for EASME staff

   Shows top-level mosaic menu

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../../modules/enterprises/enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $profile := user:get-user-profile()
let $person := $profile/parent::Person
let $enterprises := enterprise:get-my-enterprises()
let $hm := count($enterprises)
return
  if ($hm > 1) then
    <Page StartLevel="1" skin="fonts">
      <Window>My SMEi companies</Window>
      <Content>
        <Title Level="2" style="margin-bottom:0">Companies of which you are member</Title>
        <p class="text-info" style="margin-bottom:20px"><i>Select a company from the list below to see its dashboard</i></p>
        <ul>
        {
          for $e in $enterprises
          return
            <li>
              {
              if (not(enterprise:is-valid($e))) then
                <span>{$e/Information/Name} (<i>company status marked as invalid</i>)</span>
              else if (not(enterprise:has-projects($e))) then
                <span>{$e/Information/Name} (<i>no grant agreement signed or all projects are terminated</i>)</span>
              else
                <a href="{$cmd/@base-url}{$e/Id}">{$e/Information/Name}</a>
              }
            </li>
        }
        </ul>
      </Content>
    </Page>
  else
    <Redirected>{oppidum:redirect(concat($cmd/@base-url,'me'))}</Redirected>
