xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Case formulars

   December 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";

declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Converts an enterprise PostalCode to a list of nutscodes 
   Falls back to the country code
   ======================================================================
:)
declare function local:nuts-from-postal( $e as element()? ) as xs:string* {
  let $country := $e/Address/Country/text()
  let $res := 
    if ($e/Address/PostalCode and $country) then
      let $prefix := substring($e/Address/PostalCode/text(), 1, 2)
      return
        distinct-values(
          for $c in fn:collection('/db/sites/nuts')//Nuts[@Country eq $country]/Code[Postal eq $prefix]
          order by number($c/Err) ascending
          return $c/Nuts/text()
        )
    else
      ()
  return
    if (empty($res)) then $country else $res
}; 

(: ======================================================================
   Utility to configure an autofill filter on a referencial input field 
   for transclusion purpose
   NOT USED
   ======================================================================
:)
declare function local:autofill( $cmd as element(), $url as xs:string, $target as xs:string ) as xs:string {
  let $url := concat($cmd/@base-url, $url)
  let $container := 'div.c-autofill-border'
  return
    concat('autofill_url=', $url,';autofill_target=', $target, ';autofill_container=', $container)
};

(: ======================================================================
   Returns field to select challenges
   ======================================================================
:)
declare function local:gen-challenges-selector( $lang as xs:string, $noedit as xs:boolean, $section as xs:string, $tag as xs:string ) as element()* {
  let $pairs :=
      for $p in fn:doc($globals:global-information-uri)//GlobalInformation/Description[@Lang = $lang]/CaseImpact/Sections/Section[Id eq $section]/SubSections/SubSection
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

(: ======================================================================
   Generates the Enterprise field with a constant field (read only)
   and an autofill filter configured to complete the enterprise information
   DEPRECATED
   ======================================================================
:)
declare function local:gen-enterprise-readonly( $cmd as element() ) as element()* {
  <site:field Key="enterprise" filter="no">
    {
    let $autofill := concat('autofill;autofill_url=', $cmd/@base-url, 'enterprises/$_.blend?goal=autofill&amp;context=Case&amp;plugin=constant&amp;envelope=ClientEnterprise;autofill_target=.x-ClientEnterprise;autofill_container=div.c-autofill-border')
    return (
      <xhtml:span style="display:none"><xt:use types="constant" label="EnterpriseRef" param="filter={$autofill}"/></xhtml:span>,
      <xt:use types="constant" label="Name" param="class=uneditable-input span a-control"/>
      )
    }
  </site:field>
};

(: ======================================================================
   Functions to suggest EEN entities for a given case
   FIXME: regroup in a lib/suggest.xqm file ?
   ======================================================================
:)
declare function local:gen-suggested-eentity ( $project as element(), $case as element()?, $lang as xs:string, $params as xs:string ) as element()?  {
  let $nuts := system:as-user(account:get-secret-user(), account:get-secret-password(),local:nuts-from-postal($project/Information/Beneficiaries/(Coordinator | Partner)[PIC eq $case/PIC]))
  return
    if (count($nuts) > 0) then
      let $defs := <Regions>{ fn:collection($globals:regions-uri)/Region }</Regions>
      return
         let $check-country := (count($nuts) eq 1) and (string-length($nuts[1]) eq 2)
         let $pairs :=
            if ($check-country) then
              for $p in $defs/Region[Country = $nuts]
              let $n := $p/LongLabel/text()
              return
                 <Name id="{$p/Id}">{(replace($n,' ','\\ '))}</Name>
            else
              for $p in $defs/Region
              let $n := $p/LongLabel/text()
              where (some $x in $p/NutsCodes/Nuts satisfies some $y in $nuts satisfies starts-with($y, $x))
              return
                 <Name id="{$p/Id}">{(replace($n,' ','\\ '))}</Name>
        return
          if (count($pairs) > 0) then
            let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
            let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
            return
              <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_complement=town;{form:setup-select2($params)}"/>
          else
            <xt:use types="constant" param="class=uneditable-input span;noxml=true">no EEN Entity found for { string-join($nuts, ", ") }</xt:use>
    else
      <xt:use types="constant" param="class=uneditable-input span;noxml=true">check SME beneficiary country and postal code</xt:use>
};

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $goal := request:get-parameter('goal', 'read')
let $template := string(oppidum:get-resource($cmd)/@name)
let $project := request:get-parameter('project', '-1')
return
  if ($goal = 'read') then

    if ($template = 'case-information') then
      <site:view>
        <site:field Key="project-id">
          <xt:use types="constant" param="class=uneditable-input span">n/a</xt:use>
        </site:field>
      </site:view>

    else  if ($template = 'needs-analysis') then
      <site:view>
        <site:field Key="vectors" filter="no">
          { local:gen-challenges-selector($lang, true(), '1', 'VectorRef') }
        </site:field>
        <site:field Key="ideas" filter="no">
          { local:gen-challenges-selector($lang, true(), '2', 'IdeaRef') }
        </site:field>
        <site:field Key="resources" filter="no">
          { local:gen-challenges-selector($lang, true(), '3', 'ResourceRef') }
        </site:field>
        <site:field Key="partners" filter="no">
          { local:gen-challenges-selector($lang, true(), '4', 'PartnerRef') }
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
        <site:field Key="likert-scale">
          { form:gen-radio-selector-for('RatingScales', $lang, true(), 'c-inline-choice') }
        </site:field>
      </site:view>

    else
      <site:view/>

  else (: assumes 'create' or 'update' goal :)

    if ($template = 'case-information') then
      <site:view>
        <site:field Key="pic">
          { form:gen-pic-selector($project, $lang, ";multiple=no;typeahead=no") }
        </site:field>
      </site:view>
      
    else  if ($template = 'managing-entity') then
      <site:view>
        <site:field Key="assigned-eentity">
          { form:gen-selector-for-regional-entities( $lang, ";select2_dropdownAutoWidth=false;select2_complement=town;multiple=no;typeahead=yes", "LongLabel") }
        </site:field>
        <site:field Key="suggested-eentity">
          {
          let $case-no := request:get-parameter('case', '-1')
          let $case := fn:collection($globals:projects-uri)/Project[Id eq $project]/Cases/Case[No eq $case-no]
          return
            local:gen-suggested-eentity($case/../.., $case, $lang, ";multiple=no;typeahead=yes")
          }
        </site:field>
      </site:view>

    else  if ($template = 'case-management') then
      <site:view>
        <site:field Key="assigned-kam">
        { 
        let $case-no := request:get-parameter('case', '-1')
          let $case := fn:collection($globals:projects-uri)/Project[Id eq $project]/Cases/Case[No eq $case-no]
        return
          form:gen-kam-for-case-selector($case, $lang, " optional;multiple=no;typeahead=yes", $case/Management/AccountManagerRef) 
        }
        </site:field>
        <site:field Key="yes-no">
          { form:gen-selector-for('YesNoScales', $lang, ";multiple=no;typeahead=no") }
        </site:field>
      </site:view>

    else  if ($template = 'needs-analysis') then
    <site:view>
      <site:field Key="size">
        { form:gen-selector-for('Sizes', $lang, ";multiple=no;typeahead=yes;select2_minimumResultsForSearch=1") }
      </site:field>
      <site:field Key="domain-activity">
        { (:form:gen-selector-for('DomainActivities', $lang, ";multiple=no;typeahead=yes") :)
          form:gen-json-selector-for('DomainActivities', $lang,
            "multiple=no;choice2_width0=212px;choice2_width1=300px;choice2_width2=240px;choice2_closeOnSelect=true") }
      </site:field>
      <site:field Key="targeted-markets">
        { (:form:gen-selector-for('TargetedMarkets', $lang, ";multiple=yes;xvalue=TargetedMarketRef;typeahead=yes") :)
          form:gen-json-selector-for('TargetedMarkets', $lang,
          "multiple=yes;xvalue=TargetedMarketRef;choice2_width0=212px;choice2_width1=280px;choice2_width2=250px;choice2_closeOnSelect=true")
        }
      </site:field>
      <site:field Key="known-tools">
        { form:gen-selector-for('KnownTools', $lang, " optional;multiple=yes;xvalue=KnownToolRef;typeahead=yes;select2_minimumResultsForSearch=1") }
      </site:field>
      <site:field Key="sector-groups">
        { form:gen-selector-for('SectorGroups', $lang, " optional;multiple=no;typeahead=yes;select2_minimumResultsForSearch=1") }
      </site:field>
      <site:field Key="vectors" filter="no">
        { local:gen-challenges-selector($lang, false(), '1', 'VectorRef') }
      </site:field>
      <site:field Key="ideas" filter="no">
        { local:gen-challenges-selector($lang, false(), '2', 'IdeaRef') }
      </site:field>
      <site:field Key="resources" filter="no">
        { local:gen-challenges-selector($lang, false(), '3', 'ResourceRef') }
      </site:field>
      <site:field Key="partners" filter="no">
        { local:gen-challenges-selector($lang, false(), '4', 'PartnerRef') }
      </site:field>
      <site:field Key="ctx-initial" filter="no">
        { 
        (:form:gen-selector-for('InitialContexts', $lang, " optional;multiple=no;typeahead=yes;select2_width=off;class=span12") :)
        form:gen-radio-selector-for( 'InitialContexts', $lang, false())
        }
      </site:field>
      <site:field Key="ctx-target" filter="no">
        { 
        (:form:gen-selector-for('TargetedContexts', $lang, " optional;multiple=no;typeahead=yes;select2_width=off;class=span12") :)
        form:gen-radio-selector-for( 'TargetedContexts', $lang, false())
        }
      </site:field>
      <site:field Key="sex">
        <xt:use types="choice"
        values="M F"
        i18n="M F"
        param="class=span12 a-control"
        >M</xt:use>
      </site:field>
      <site:field Key="likert-scale">
        { form:gen-radio-selector-for('RatingScales', $lang, false(), 'c-inline-choice') }
      </site:field>
    </site:view>

    else
      <site:view/>
