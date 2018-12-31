xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Extension points for Activity workflow formulars

   TODO:
   - SuperGrid Constant 'html' field (for Comments in Opinions)

   November 2014 - (c) Copyright may be reserved
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
    if ($template = 'contact-persons') then
      <site:view>
        <site:field Key="persons">
          { form:gen-contact-selector($lang, ";multiple=no;typeahead=yes") }
        </site:field>
      </site:view>
    else
      <site:view/>
  else (: assumes 'read' - no 'create' :)
    <site:view/>
