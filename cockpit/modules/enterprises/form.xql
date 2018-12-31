xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Enterprise formulars

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

(: flags for hierarchical 2 levels selectors:)
declare variable $local:json-selectors := true();

(: ======================================================================
   Generate selector for two level fields like domains of activity or markets
   TODO: move to form.xqm
   ====================================================================== 
:)
declare function local:gen-hierarchical-selector ($tag as xs:string, $xvalue as xs:string?, $optional as xs:boolean, $position as xs:string, $lang as xs:string ) {
  let $filter := if ($optional) then ' optional' else ()
  let $params := if ($xvalue) then
                  concat(';multiple=yes;xvalue=', $xvalue, ';typeahead=yes')
                 else
                  ';multiple=no'
  return
    if ($local:json-selectors) then
      custom:gen-cached-json-selector-for($tag, $lang,
        concat($filter, $params, ";choice2_width1=280px;choice2_width2=300px;choice2_closeOnSelect=true;choice2_position=", $position)) 
    else
      custom:gen-cached-selector-for($tag, $lang, concat($filter, $params))
};

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
return

  if ($target = 'search') then (: Enterprise search formular :)

    <site:view>
      <site:field Key="programs">
        { custom:gen-cached-selector-for('FundingPrograms', $lang, ";multiple=yes;xvalue=FundingProgramRef;typeahead=no") }
      </site:field>
      <site:field Key="POs">
        { custom:gen-po-selector(";multiple=yes;xvalue=ProjectOfficerRef;typeahead=yes", 'span') }
      </site:field>
      <site:field Key="acronyms">
        { custom:gen-all-projects-acronym('en', ';multiple=yes;xvalue=Acronym;typehead=yes') }
      </site:field>
      <site:field Key="calls">
        { custom:gen-cached-json-selector-for( ('SMEiCalls', 'FTICalls', 'FETCalls') ,"en", ";multiple=yes;xvalue=CallRef;typeahead=no;choice2_width1=300px;choice2_width2=300px;choice2_closeOnSelect=true") }
      </site:field>
      <site:field Key="terminations">
        { custom:gen-cached-selector-for('TerminationFlags', $lang, ";multiple=yes;xvalue=TerminationFlagRef;typeahead=no") }
      </site:field>
      <site:field Key="sme">
        { custom:gen-cached-selector-for('CompanyTypes', $lang, ";multiple=yes;xvalue=CompanyTypeRef;typeahead=no") }
      </site:field>
      <site:field Key="validity">
        { custom:gen-cached-selector-for('StatusFlags', $lang, ";multiple=yes;xvalue=StatusFlagRef;typeahead=no") }
      </site:field>
      <site:field Key="enterprises">
        { custom:gen-enterprise-selector($lang, ";multiple=yes;xvalue=EnterpriseRef;typeahead=yes") }
      </site:field>
      <site:field Key="towns">
        { custom:gen-town-selector($lang, ";multiple=yes;xvalue=Town;typeahead=yes") }
      </site:field>
      <site:field Key="countries">
        { form:gen-cached-selector-for('Countries', $lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
      </site:field>
      <site:field Key="sizes">
        { form:gen-cached-selector-for('Sizes', $lang, ";multiple=yes;xvalue=SizeRef;typeahead=yes;select2_minimumResultsForSearch=1") }
      </site:field>
      <site:field Key="domains-of-activities">
        { local:gen-hierarchical-selector('DomainActivities', 'DomainActivityRef', false(), 'left', $lang) }
      </site:field>
      <site:field Key="targeted-markets">
        { local:gen-hierarchical-selector('TargetedMarkets', 'TargetedMarketRef', false(), 'left', $lang) }
      </site:field>
      <site:field Key="company-type">
        { form:gen-cached-selector-for('CompanyTypes', $lang, ";multiple=yes;xvalue=CompanyTypeRef;typeahead=yes") }
      </site:field>
      <site:field Key="persons">
        { custom:gen-member-selector($lang, ";multiple=yes;xvalue=PersonKey;typeahead=yes") }
      </site:field>
    </site:view>

  else if ($target = 'import') then

    <site:view>
      <site:field Key="call">
        { form:gen-cached-selector-for('CutOffDates', $lang, ";multiple=no;select2_width=150px") }
      </site:field>
      <site:field Key="mode">
        <xt:use types="choice" param="appearance=full;multiple=no;class=c-inline-choice" values="dry run">dry</xt:use>
      </site:field>
    </site:view>

  else

    if ($goal = 'read') then

      <site:view>
      </site:view>

    else if ($target = 'address') then (: assumes update goal :)

      <site:view>
        <site:field Key="enterprise" filter="no">
          <xt:use types="input" param="filter=optional event;class=span a-control;required=true;" label="Name"></xt:use>
        </site:field>
        <site:field Key="country">
          {
          if (request:get-parameter-names() = "iso3") then
            form:gen-cached-selector-for('ISO3Countries', $lang, " optional;multiple=no;typeahead=yes")
          else
            form:gen-cached-selector-for('Countries', $lang, " optional;multiple=yes;typeahead=yes") }
        </site:field>
      </site:view>

    else if ($target = 'statistics') then (: assumes update goal :)

      <site:view>
        <site:field Key="size">
          { form:gen-cached-selector-for('Sizes', $lang, " optional;multiple=no;typeahead=yes;select2_minimumResultsForSearch=1") }
        </site:field>
        <site:field Key="service-product-offered">
          <!-- { local:gen-hierarchical-selector('DomainActivities', (), true(), 'right', $lang) } -->
          { local:gen-hierarchical-selector('DomainActivities', 'DomainActivityRef', false(), 'right', $lang) }
        </site:field>
        <site:field Key="targeted-markets">
          { local:gen-hierarchical-selector('TargetedMarkets', 'TargetedMarketRef', true(), 'right', $lang) }
        </site:field>
        <site:field Key="thematics-topics">
          { custom:gen-selector3-for('ThematicsTopics', $lang, " optional;multiple=yes;xvalue=ThematicsTopicRef;typeahead=yes") }
        </site:field>
        <site:field Key="countries-selling-to">
          { form:gen-selector-for("ISO3166Countries", $lang, " optional;multiple=yes;xvalue=ISO3166CountryRef;typeahead=yes") }
        </site:field>
        <site:field Key="clients">
          { form:gen-cached-selector-for('Clients', $lang, " optional;xvalue=ClientRef;multiple=yes;typeahead=yes") }
        </site:field>
        <site:field Key="services-and-products-looking-for">
          { local:gen-hierarchical-selector('DomainActivities', 'DomainActivityRef', false(), 'right', $lang) }
        </site:field>  
      </site:view>

    else if ($target = 'status') then (: assumes update goal :)

      <site:view>
        <site:field Key="conform-sme">
          { form:gen-cached-selector-for('YesNoScales', $lang, ";multiple=no") }
        </site:field>
        <site:field Key="status-flag">
          { 
          let $use := form:gen-cached-selector-for('StatusFlags', $lang, ";multiple=no") 
          return (: FIXME: adds default selection to generic function :)
            <xt:use>{ $use/@*, '2' }</xt:use>
          }
        </site:field>
        <site:field Key="termination-flag">
          { form:gen-cached-selector-for('TerminationFlags', $lang, " optional;multiple=no") }
        </site:field>
      </site:view>

    else (: unlikely :)

      <site:view>
      </site:view>
