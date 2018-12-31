xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Feedback formulars

   October 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Generates all selectors for all satisfaction formulars
   Factorization makes code easier to maintain
   Set $readonly to true() for 'read' version, false() otherwise
   ====================================================================== 
:)
declare function local:gen-satisfaction-fields( $readonly as xs:boolean, $lang as xs:string ) as element()* {
  <site:field Prefix="yesno_">
    { custom:gen-radio-selector-for('YesNoScales', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="fair_satisfaction">
    { custom:gen-radio-selector-for('FairSatisfactionLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="recommendation">
    { custom:gen-radio-selector-for('RecommendationLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>
};

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
return
  if ($goal = 'read') then
    <site:view>
      { local:gen-satisfaction-fields(true(), $lang)}
    </site:view>
  else
    if ($target = 'investor') then
      <site:view>
        { local:gen-satisfaction-fields(false(), $lang)}
      </site:view>
    else 
      <site:view>
      </site:view>
