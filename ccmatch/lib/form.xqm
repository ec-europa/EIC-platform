xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Functions to generate extension points for the application formulars.
   Each function has to localize its results in the current language.

   See also :
   -'select2' documentation at http://ssire.github.io/axel-forms/editor/editor.xhtml#filters/Select2

   November 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace form = "http://oppidoc.com/oppidum/form";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "../modules/suggest/match.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Helper function to generate XTiger param attribute when using 'select2' filter
   ======================================================================
:)
declare function form:setup-select2 ( $params as xs:string ) as xs:string {
  if (ends-with($params,"px")) then
    (: assumes it contains a custom width like in stage-search :)
    concat("select2_dropdownAutoWidth=true;class=a-control;filter=select2", $params)
  else
    concat("select2_dropdownAutoWidth=true;select2_width=off;class=span12 a-control;filter=select2", $params)
};

(: ======================================================================
   Generates fake field for fields not yet available
   ======================================================================
:)
declare function form:gen-unfinished-selector ( $lang as xs:string, $params as xs:string ) as element() {
  <xt:use types="choice"
    param="class=span12 a-control;{$params}"
    values="1 2 3 4 5"
    i18n="Un Deux Trois Quatre Cinq"
    />
};

(: ======================================================================
   Generates XTiger XML 'choice' element for a given selector as a drop down list
   TODO:
   - caching
   ======================================================================
:)
declare function form:gen-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $concat := if (starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs/@Label, 'V+') else string($defs/@Label)
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := $p/*[local-name(.) eq string($defs/@Value)]/text()
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/*[local-name(.) eq $label]
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Same as above but uses an explicit label to identify the selector's label
   ======================================================================
:)
declare function form:gen-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string, $label as xs:string ) as element() {
  let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := $p/*[local-name(.) eq string($defs/@Value)]/text()
        let $l := $p/*[local-name(.) eq $label]
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for a given selector as a radio button box
   TODO:
   - caching
   ======================================================================
:)
declare function form:gen-radio-selector-for( $name as xs:string, $lang as xs:string, $noedit as xs:boolean, $class as xs:string ) as element()* {
  let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $concat := if (starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs/@Label, 'V+') else string($defs/@Label)
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := $p/*[local-name(.) eq string($defs/@Value)]/text()
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/*[local-name(.) eq $label]
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
        return
          if ($noedit) then
            <xt:use types="choice" param="appearance=full;multiple=no;class={$class} readonly;noedit=true" values="{$ids}" i18n="{$names}"/>
          else
            <xt:use types="choice" param="filter=optional;appearance=full;multiple=no;class={$class}" values="{$ids}" i18n="{$names}"/>
};

declare function form:gen-radio-selector-for( $name as xs:string, $lang as xs:string, $noedit as xs:boolean ) as element()* {
  form:gen-radio-selector-for($name, $lang, $noedit, 'a-select-box')
};

(: ======================================================================
   Generates a 'choice2' selector with JSON menu definition
   Notes : only applies to two level selection (NOGA and Markets)
   TODO: cache
   ======================================================================
:)
declare function form:gen-json-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $json :=
    <json>
      {
      for $g in fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]/Group
      return
        element { concat('_', $g/Code/text()) }
        {(
        element { '__label' } { $g/Name/text() },
        for $o in $g//Option
        return
          element { concat('_', $o/Code/text()) } {
            $o/Name/text()
          }
        )}
      }
    </json>
  let $res := util:serialize($json, 'method=json')
  let $unfilter := replace($res, '"_', '"')
  return
   <xt:use types='choice2' param="{$params}" values='{ $unfilter }'/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a possible contact for coach

   TODO: [UserProfile/Roles/Role/FunctionRef eq "4"]
   ======================================================================
:)
declare function form:gen-contact-selector( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef ne '4'] (: all but coaches :)
      let $fn := if ($p/Information/Name/FirstName) then $p/Information/Name/FirstName else concat('(', $p/Id, ')')
      let $ln := if ($p/Information/Name/LastName) then $p/Information/Name/LastName else 'Anonymous'
      order by $ln ascending
      return
         <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a person
   ======================================================================
:)
declare function form:gen-person-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person
      let $fn := if ($p/Information/Name/FirstName) then $p/Information/Name/FirstName else concat('(', $p/Id, ')')
      let $ln := if ($p/Information/Name/LastName) then $p/Information/Name/LastName else 'Anonymous'
      order by $ln ascending
      return
         <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a coach
   Returns list of all coaches independently of coach preferences / status
   NOTE: $host could be used to restrict to one Host
   ======================================================================
:)
declare function form:gen-coach-selector ( $lang as xs:string, $params as xs:string, $host as xs:string ) as element() {
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef eq "4"]
      let $fn := if ($p/Information/Name/FirstName) then $p/Information/Name/FirstName else concat('(', $p/Id, ')')
      let $ln := if ($p/Information/Name/LastName) then $p/Information/Name/LastName else 'Anonymous'
      order by $ln ascending
      return
         <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a coach
   Filters by coach preferences depending on Host making the request
   ======================================================================
:)
declare function form:gen-coach-selector-for-host ( $lang as xs:string, $params as xs:string, $host as xs:string ) as element() {
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef eq "4"]
      let $fn := if ($p/Information/Name/FirstName) then $p/Information/Name/FirstName else concat('(', $p/Id, ')')
      let $ln := if ($p/Information/Name/LastName) then $p/Information/Name/LastName else 'Anonymous'
      where match:assert-coach($p, $host)
      order by $ln ascending
      return
         <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a person's role
   ======================================================================
:)
declare function form:gen-role-selector ( $lang as xs:string, $params as xs:string ) as element() {
let $pairs :=
      for $p in fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = $lang]/Functions/Function
      let $n := $p/Name
      order by $n ascending
      return
         <Name id="{$p/Id/text()}">{(replace($n,' ','\\ '))}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a  Case Impact
   TODO: 
   - migration to use Selector / Group generic structure to use gen-selector-for
   ======================================================================
:)
declare function form:gen-challenges-selector-for ( $root as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
        for $p in fn:collection($globals:global-info-uri)//Description[@Lang = $lang]/CaseImpact/Sections/Section[SectionRoot eq $root]/SubSections/SubSection
        let $n := $p/SubSectionName
        return
           <Name id="{$p/Id/text()}">{(replace($n,' ','\\ '))}</Name>
  return
   let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
   let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
   return
     <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates selector for realms
   ======================================================================
:)
declare function form:gen-realm-selector ( $params as xs:string ) as element() {
let $rlms :=
      for $r in fn:doc(oppidum:path-to-config('security.xml'))/Realms/Realm[@Name ne 'EXIST']
      let $n := string($r/@Name)
      order by $n ascending
      return $n
  return
    <xt:use types="choice" values="{ string-join($rlms, ' ') }" param="{form:setup-select2($params)}"/>
};
