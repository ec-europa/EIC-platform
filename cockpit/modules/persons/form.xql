xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Person search and Person formulars

   FIXME:
   - replace form:gen-coach-selector by form:gen-person-selector when goal is to search ?
   - generate (and localize) sex, civility and function fields from DB content ?

   September 2013 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace httpclient = "http://exist-db.org/xquery/httpclient";

import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";


let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
return
  if ($goal = ('update','create')) then
    <site:view>
      <site:field Key="realm">
        { custom:gen-realm-selector(";multiple=no;typeahead=no") }
      </site:field>
      <site:field Key="sex">
        <xt:use types="choice" values="M F" i18n="M F" param="class=span12 a-control">M</xt:use>
      </site:field>
      <site:field Key="corporate">
        { form:gen-selector-for('CorporateFunctions', $lang, " event;multiple=yes;xvalue=CorporateFunctionRef;typeahead=yes")}
      </site:field>
      <site:field Key="spokenlanguages">
        { form:gen-selector-for('SpokenLanguages', $lang, " event;multiple=yes;xvalue=SpokenLanguageRef;typeahead=yes")}
      </site:field>
    </site:view>
  else (: 'read' - only constant fields  :)
    <site:view/>
