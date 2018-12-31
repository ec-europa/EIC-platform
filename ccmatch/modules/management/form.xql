xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Extension points for Activity workflow formulars

   TODO:
   - SuperGrid Constant 'html' field (for Comments in Opinions)

   November 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
(:import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";:)

declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $goal := request:get-parameter('goal', 'read')
let $template := string(oppidum:get-resource($cmd)/@name)
return
  if ($goal = ('update', 'create')) then
    if ($template = 'user') then
      <site:view>
        <site:field Key="roles">
          { form:gen-role-selector($lang, ";multiple=yes;xvalue=RoleRef;typeahead=yes") }
        </site:field>
        <site:field Key="countries">
          { form:gen-selector-for('Countries', $lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
        </site:field>
        <site:field Key="persons">
          { form:gen-person-selector($lang, ";multiple=yes;xvalue=PersonRef;typeahead=yes") }
        </site:field>
      </site:view>
    else if ($template = ('account', 'login')) then
      <site:view/>
    else if ($template = 'availabilities') then
      <site:view>
        <site:field Key="availability">
          { form:gen-selector-for('YesNoAvails', $lang, ";multiple=no;typeahead=yes") }
        </site:field>
      </site:view>
    else if ($template = 'visibilities') then
      <site:view>
        <site:field Key="visibility">
          { form:gen-selector-for('YesNoAccepts', $lang, ";multiple=no;typeahead=yes") }
        </site:field>
      </site:view>
    else
      <site:view/>
  else (: assumes 'read' - no 'create' :)
    <site:view/>
