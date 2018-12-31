xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Team formulars

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

(: flags for hierarchical 2 levels selectors:)
declare variable $local:json-selectors := true();

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
return

  if ($goal = 'read') then

    <site:view>
    </site:view>

  else if ($target = 'member') then (: assumes update goal :)

    <site:view>
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

  else if ($target = 'search') then

    <site:view>
      <site:field Key="programs">
        { custom:gen-cached-selector-for('FundingPrograms', $lang, ";multiple=yes;xvalue=FundingProgramRef;typeahead=no") }
      </site:field>
      <site:field Key="acronyms">
        { custom:gen-all-projects-acronym('en', ';multiple=yes;xvalue=Acronym;typehead=yes') }
      </site:field>
      <site:field Key="terminations">
        { custom:gen-cached-selector-for('TerminationFlags', $lang, ";multiple=yes;xvalue=TerminationFlagRef;typeahead=no") }
      </site:field>
      <site:field Key="validity">
        { custom:gen-cached-selector-for('StatusFlags', $lang, ";multiple=yes;xvalue=StatusFlagRef;typeahead=no") }
      </site:field>
      <site:field Key="company-type">
        { form:gen-cached-selector-for('CompanyTypes', $lang, ";multiple=yes;xvalue=CompanyTypeRef;typeahead=yes") }
      </site:field>
      <site:field Key="adstatus">
        { form:gen-cached-selector-for('StatusAdmissions', $lang, ";multiple=yes;xvalue=StatusAdmissionRef;typeahead=yes") }
      </site:field>
      <site:field Key="persons">
        { custom:gen-member-selector($lang, ";multiple=yes;xvalue=PersonKey;typeahead=yes") }
      </site:field>
      <site:field Key="access">
        { form:gen-cached-selector-for('AccessLevels', $lang, ";multiple=yes;xvalue=StatusRef;typeahead=yes") }
      </site:field>
      <site:field Key="purpose">
        { 
        if (custom:check-settings('scaleup', 'mode', 'on')) then 
          custom:gen-radio-selector-for('AccreditationTypes', $lang, false(), 'c-inline-choice', (), '2')
        else
          custom:gen-radio-selector-for('AccreditationTypes', $lang, false(), 'c-inline-choice', (), ('2', '3'))
        }
      </site:field>
      <site:field Key="enterprises">
        { custom:gen-enterprise-selector($lang, ";multiple=yes;xvalue=EnterpriseRef;typeahead=yes") }
      </site:field>
      <site:field Key="PO">
        { custom:gen-po-selector(";multiple=yes;xvalue=ProjectOfficerRef;typeahead=yes", 'span') }
      </site:field>
      <site:field Key="functions">
        { form:gen-cached-selector-for('Functions', $lang, ";multiple=yes;xvalue=FunctionRef;typeahead=yes") }
      </site:field>
      
    </site:view>

  else (: unlikely :)

    <site:view>
    </site:view>
