xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Regions search and Regions formulars

   December 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
return
  if ($target = 'regions') then (: Region search formular :)
    <site:view>
      <site:field Key="nuts">
        { form:gen-selector-for-nuts($lang, ";multiple=yes;xvalue=Nuts;typeahead=yes", "span2") }
      </site:field>
      <site:field Key="countries">
        { form:gen-selector-for('Countries', $lang, ";multiple=yes;xvalue=CountryRef;typeahead=yes") }
      </site:field>
      <site:field Key="regions">
        { form:gen-selector-for-regional-entities($lang, ";select2_complement=town;multiple=yes;xvalue=RegionalEntityRef;typeahead=yes", "LongLabel") }
      </site:field>
      <site:field Key="members">
        { form:gen-person-with-role-selector(('region-manager', 'kam'), $lang, ";multiple=yes;typeahead=yes;xvalue=MemberRef", ()) }
      </site:field>
    </site:view>
  else (: assumes generic RegionalEntity formular  :)
    if ($goal = 'read') then
      <site:view>
      </site:view>
    else
      <site:view>
        {
        if ($goal = 'create') then
          <site:field Key="acronym">
            { form:gen-selector-for-regional-entities( $lang, ";select2_complement=town;select2_tags=yes;typeahead=yes") }
          </site:field>
        else
          <site:field Key="acronym" filter="no">
            <xt:use types="input" param="filter=event;class=span a-control;required=true;" label="Acronym"></xt:use>
          </site:field>
        }
        <site:field Key="members">
        { 
        form:gen-person-selector($lang, ";multiple=yes;xvalue=MemberRef;typeahead=yes") 
        }
        </site:field>
        <site:field Key="country">
          { form:gen-selector-for('Countries', $lang, ";multiple=no;typeahead=yes") }
        </site:field>
      </site:view>

