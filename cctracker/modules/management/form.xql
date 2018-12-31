xquery version "1.0";
(: ------------------------------------------------------------------
   Coaching application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Form fields generation for user management module

   March 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)
declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
return
  if ($target = ('profile', 'remote')) then
    <site:view>
      <site:field Key="realm">
        { form:gen-realm-selector(";multiple=no;typeahead=no") }
      </site:field>
      <site:field Key="function">
        { form:gen-role-selector($lang, ";multiple=no;typeahead=no") }
      </site:field>
      <site:field Key="services">
        { form:gen-selector-for('Services', $lang, ";multiple=yes;typeahead=no;xvalue=ServiceRef") }
      </site:field>
      <site:field Key="cantonal-antenna">
        { form:gen-selector-for-regional-entities( $lang, " optional;select2_complement=town;multiple=no;typeahead=yes") }
      </site:field>
      <site:field Key="nuts">
        { form:gen-selector-for-nuts( $lang, " optional;select2_complement=town;multiple=yes;xvalue=NutsRef;typeahead=yes", '') }
      </site:field>
    </site:view>
  else (: only constant fields  :)
    <site:view/>
