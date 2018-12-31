xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Case formulars

   December 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

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
declare function local:gen-suggested-eentity ( $case as element()?, $lang as xs:string, $params as xs:string ) as element()?  {
  let $nuts := local:nuts-from-postal($case/Information/ClientEnterprise)
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
return
  if ($goal = 'read') then

    if ($template = 'project-information') then
      <site:view>
        <site:field Key="project-id">
          <xt:use types="constant" param="class=uneditable-input span">n/a</xt:use>
        </site:field>
        <site:field Key="summary" filter="no">
          <xt:use types="html" param="class=span a-control" label="Summary"/>
        </site:field>
      </site:view>
    else
      <site:view/>

  else (: assumes 'create' or 'update' goal :)

    if ($template = 'project-information') then
      <site:view>
        <site:field Key="summary" filter="no">
          <xt:use types="html" param="class=span a-control" label="Summary"/>
        </site:field>
      </site:view>
    else
      <site:view/>
