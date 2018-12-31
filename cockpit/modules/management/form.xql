xquery version "1.0";
(: ------------------------------------------------------------------
   Coaching application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Form fields generation for user management module

   March 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
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
declare function local:gen-hierarchical-selector ($tag as xs:string, $xvalue as xs:string?, $optional as xs:boolean, $position as xs:string, $lang as xs:string ) as element() {
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
  if ($target eq 'roles') then
    <site:view>
      <site:field Key="function">
        { 
        let $filter := fn:collection($globals:global-info-uri)//Description[@Role = 'normative']/Selector[@Name eq 'Functions']//Option[@AdminPanel eq 'static' or @Scope eq 'scaleup']/Value
        return
          form:gen-selector-for-filter('Functions', $lang, ";multiple=no;typeahead=yes", $filter)
        }
      </site:field>
      <site:field Key="program">
        { form:gen-selector-for('EventsPrograms', $lang, " optional;multiple=yes;xvalue=ProgramId;typeahead=yes") }
      </site:field>
      <site:field Key="enterprises">
        { custom:gen-enterprise-selector($lang, " optional;multiple=yes;xvalue=EnterpriseRef;typeahead=yes") }
      </site:field>

      <!-- ScaleUP-EU-Regions 
           Regions must be limited to a country
      -->
      <site:field Key="regions">
        { form:gen-selector-for('ScaleUP-EU-Regions', $lang, " optional;multiple=yes;xvalue=RegionRef;typeahead=no") }
      </site:field>
      <!-- Countries -->
      <site:field Key="countries">
        { form:gen-selector-for('ISO3166Countries', $lang, " optional;multiple=yes;xvalue=CountryRef;typeahead=no") }
      </site:field>
      <site:field Key="service-product-offered">
        { local:gen-hierarchical-selector('DomainActivities', 'DomainActivityRef', false(), 'right', $lang) }
      </site:field>
      <site:field Key="targeted-markets">
        { local:gen-hierarchical-selector('TargetedMarkets', 'TargetedMarketRef', false(), 'right', $lang) }
      </site:field>
      <!-- ScaleUP-EU-Scope -->
      <site:field Key="scope">
        { custom:gen-radio-selector-for('ScaleUP-EU-Scope', $lang, false(), 'c-inline-choice',  ()) }
      </site:field>
    </site:view>
  else (: only constant fields  :)
    <site:view/>
