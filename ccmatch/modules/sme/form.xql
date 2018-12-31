xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for SME profile

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";

declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";


(: ======================================================================
   Returns field to select challenge weights for selected challenges
   FIXME: case and activity should be coded into template URL to be RESTfull
   ======================================================================
:)
declare function local:gen-challenge-weights( $lang as xs:string, $noedit as xs:boolean, $section as xs:string ) as element()* {
  let $xtra := if ($noedit) then ';noedit=true' else ''
  let $model := fn:collection($globals:global-info-uri)//GlobalInformation/Description[@Lang eq 'en']/CaseImpact/Sections/Section[Id eq $section]
  let $root := $model/SectionRoot
  let $pairs := 
      for $p in $model/SubSections/SubSection
      let $n := $p/SubSectionName
      return
         <Name id="{string($p/Id)}">{$n/text()}</Name>
  return
    if (count($pairs) > 0) then
      for $n in $pairs
      return
        <xhtml:p style="margin-bottom:10px"><xhtml:span style="display:block;margin-right:10px;float:left;width:240px;color:#004563">{$n/text()}</xhtml:span> <xt:use label="{$root}-{string($n/@id)}" types="choice" param="appearance=full;multiple=no;class=c-inline-choice{$xtra}" values="1 2 3" i18n="no medium high"/></xhtml:p>
    else
      <xhtml:p style="margin-bottom:10px;font-style:italic;color:lightgray">no challenge in needs analysis at coaching activity creation time</xhtml:p>
};

(: ======================================================================
   Returns field to select challenges
   ======================================================================
:)
declare function local:gen-challenges-selector( $lang as xs:string, $noedit as xs:boolean, $section as xs:string, $tag as xs:string ) as element()* {
  let $pairs :=
      for $p in fn:collection($globals:global-info-uri)//GlobalInformation/Description[@Lang = $lang]/CaseImpact/Sections/Section[Id eq $section]/SubSections/SubSection
      let $n := $p/SubSectionName
      return
         <Name id="{string($p/Id)}">{(replace($n,' ','\\ '))}</Name>
  let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
  let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
  return
    if ($noedit) then
      <xt:use types="choice" param="appearance=full;xvalue={$tag};multiple=yes;class=a-select-box readonly;noedit=true" values="{$ids}" i18n="{$names}"/>
    else
      <xt:use types="choice" param="appearance=full;xvalue={$tag};multiple=yes;class=a-select-box" values="{$ids}" i18n="{$names}"/>
};

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $goal := request:get-parameter('goal', 'read')
let $template := string(oppidum:get-resource($cmd)/@name)
return
  if ($goal = 'read') then

     if ($template = 'profile') then
      <site:view>
        <site:field Key="weights-vectors" filter="no">
          { local:gen-challenge-weights($lang, true(), '1') }
        </site:field>
        <site:field Key="weights-ideas" filter="no">
          { local:gen-challenge-weights($lang, true(), '2') }
        </site:field>
        <site:field Key="weights-resources" filter="no">
          { local:gen-challenge-weights($lang, true(), '3') }
        </site:field>
        <site:field Key="weights-partners" filter="no">
          { local:gen-challenge-weights($lang, true(), '4') }
        </site:field>
        <site:field Key="ctx-initial" filter="no">
          { 
          form:gen-radio-selector-for('InitialContexts', $lang, true())
          }
        </site:field>
        <site:field Key="ctx-target" filter="no">
          { 
          form:gen-radio-selector-for('TargetedContexts', $lang, true())
          }
        </site:field>
      </site:view>

    else
      <site:view/>

  else (: assumes 'create' or 'update' goal :)

    if ($template = 'profile') then
    <site:view>
      <site:field Key="domain-activity">
        { 
        (:form:gen-selector-for('DomainActivities', $lang, ";multiple=no;typeahead=yes") :)
        form:gen-json-selector-for('DomainActivities', $lang, "multiple=no;choice2_width0=212px;choice2_width1=300px;choice2_width2=240px;choice2_closeOnSelect=true") }
      </site:field>
      <site:field Key="targeted-markets">
        { 
        (:form:gen-selector-for('TargetedMarkets', $lang, ";multiple=yes;xvalue=TargetedMarketRef;typeahead=yes") :)
        form:gen-json-selector-for('TargetedMarkets', $lang, "multiple=yes;xvalue=TargetedMarketRef;choice2_width0=212px;choice2_width1=280px;choice2_width2=250px;choice2_closeOnSelect=true")
        }
      </site:field>
      <site:field Key="weights-vectors" filter="no">
        { local:gen-challenge-weights($lang, false(), '1') }
      </site:field>
      <site:field Key="weights-ideas" filter="no">
        { local:gen-challenge-weights($lang, false(), '2') }
      </site:field>
      <site:field Key="weights-resources" filter="no">
        { local:gen-challenge-weights($lang, false(), '3') }
      </site:field>
      <site:field Key="weights-partners" filter="no">
        { local:gen-challenge-weights($lang, false(), '4') }
      </site:field>
      <site:field Key="ctx-initial" filter="no">
        { 
        form:gen-radio-selector-for( 'InitialContexts', $lang, false())
        }
      </site:field>
      <site:field Key="ctx-target" filter="no">
        { 
        form:gen-radio-selector-for( 'TargetedContexts', $lang, false())
        }
      </site:field>
      <site:field Key="service">
        { form:gen-selector-for('Services', $lang, ";multiple=no;typeahead=yes") }
      </site:field>
    </site:view>

    else
      <site:view/>
