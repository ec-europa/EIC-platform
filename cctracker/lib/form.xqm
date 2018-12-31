xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

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
import module namespace display = "http://oppidoc.com/oppidum/display" at "display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "access.xqm";
import module namespace cache = "http://oppidoc.com/ns/cctracker/cache" at "cache.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "services.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "util.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";

declare option exist:serialize "method=xml media-type=text/xml";

declare function form:setup-select2 ( $params as xs:string ) as xs:string {
  if (ends-with($params,"px")) then
    (: assumes it contains a custom width like in stage-search :)
    concat("select2_dropdownAutoWidth=true;class=a-control;filter=select2", $params)
  else
    concat("select2_dropdownAutoWidth=true;select2_width=off;class=span12 a-control;filter=select2", $params)
};

(: ======================================================================
   Converts imported coach profile information into profile information
   model for editing
   ====================================================================== 
:)
declare function form:gen-coach-for-editing( $imported as element() ) {
  <Person>
    { 
    $imported/(Sex | Civility | Name | Contacts),
    if ($imported/Id) then
      $imported/Id
    else 
      (),
    if ($imported/Country) then
      <Address>{ $imported/Country }</Address>
    else
      (),
    if ($imported/Email) then
      <Email>{ $imported/Email/text() }</Email>
    else
      ()
    }
  </Person>
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
   Generates XTiger XML 'choice' element for selecting a coach (for /stage)
   Optimized version showing only coach with an activity
   ======================================================================
:)
declare function form:gen-coach-selector-OFF ( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $ref in distinct-values(fn:collection($globals:projects-uri)//ResponsibleCoachRef[. ne '']/text())
      let $p := fn:collection($globals:persons-uri)//Person[Id eq $ref]
      let $fn := if ($p) then $p/Name/FirstName else "reference"
      let $ln := if ($p) then $p/Name/LastName else "Unknown"
      order by $ln ascending
      return
         <Name id="{$ref}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}</Name>
  return
    (: FIXME: test count :)
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a coach (for /stage)
   Optimized version showing any coach
   TODO: caching mechanism
   ======================================================================
:)
declare function form:gen-coach-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef eq "4"] 
      let $fn := $p/Name/FirstName
      let $ln := $p/Name/LastName
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
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   FIXME: handle case with no Person in database (?)
   ======================================================================
:)
declare function form:gen-person-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person 
      let $fn := $p/Name/FirstName
      let $ln := $p/Name/LastName
      where ($p/Name/LastName/text() ne '')
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
   Same as function form:gen-person-selector with a restriction to a given Role
   ======================================================================
:)
declare function form:gen-person-with-role-selector ( $roles as xs:string+, $lang as xs:string, $params as xs:string, $class as xs:string? ) as element() {
  let $roles-ref := access:get-function-ref-for-role($roles)
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person[UserProfile//Role[FunctionRef = $roles-ref]]
      let $fn := $p/Name/FirstName
      let $ln := $p/Name/LastName
      where ($p/Name/LastName/text() ne '')
      order by $ln ascending
      return
         <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      if ($ids) then
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
      else
        <xt:use types="constant" param="noxml=true;class=uneditable-input {$class}">Not available</xt:use>
};

(: ======================================================================
   Same as function form:gen-person-selector with a restriction to a given Role
   Get the list of accepted Coach on coatchmatch
   ======================================================================
:)
declare function form:gen-person-with-role-selector-service ( $roles as xs:string+, $lang as xs:string, $params as xs:string, $class as xs:string? ) as element() {
  let $payload := <Export><All/></Export>
  let $coaches := services:post-to-service('ccmatch-public', 'ccmatch.export', $payload, "200")   
  let $mapselector := 
    map:new(
      for $coach in $coaches//Coach[Email ne ''][AccreditationRef eq '4'][WorkingRankRef eq '1'][not(YesNoAvailRef) or (YesNoAvailRef eq '1')]
        return
          map:entry(
            $coach/Email
            ,
            (
            form:gen-coach-for-editing($coach),
            util:declare-option("exist:serialize", "method=xml media-type=text/xml")
            )
          )
    )  
  let $roles-ref := access:get-function-ref-for-role($roles)
  let $mapexistingcoaches :=
    map:new(
      for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[FunctionRef/text() eq $roles-ref]]
        return
          map:entry(
            $p/Contacts/Email,$p/Id
          )
    )
  let $pairs :=
           for $cid in map:keys($mapselector)
          let $tmpfn := map:get($mapselector, $cid)/Name/FirstName/text()          
          let $fn :=   misc:trim($tmpfn)
          let $ln := map:get($mapselector, $cid)/Name/LastName/text()
          where (map:get($mapselector, $cid)/Name/LastName/text() ne '')
          order by $ln ascending
          return
            let $tmpid := 
              if (map:contains($mapexistingcoaches, $cid)) then 
                map:get($mapexistingcoaches, $cid)
              else 
                map:get($mapselector, $cid)//Email/text()                         
            let $id :=   misc:trim($tmpid)
            return
              let $tempStr := concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))                 
              return 
              if ($id) then
                <Name id="{$id}">{ $tempStr }</Name>
              else if (exists(map:get($mapselector, $cid)//Email)) then                
                <Name id="{map:get($mapselector, $cid)//Email/text()}">{ $tempStr }</Name>
              else
                () 
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      if ($ids) then
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
      else
        <xt:use types="constant" param="noxml=true;class=uneditable-input {$class}">Not available</xt:use>
};

(: ======================================================================
  Same as form:gen-person-selector but with person's enterprise as a satellite
  It doubles request execution times
   ======================================================================
:)
declare function form:gen-person-enterprise-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person 
      let $fn := $p/Name/FirstName
      let $ln := $p/Name/LastName
      let $pe := $p/EnterpriseRef/text()
      order by $ln ascending
      return
        let $en := if ($pe) then fn:doc($globals:enterprises-uri)//Enterprise[Id = $pe]/Name/text() else ()
        return
          <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}{if ($en) then concat('::', replace($en,' ','\\ ')) else ()}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_complement=town;{form:setup-select2($params)}"/>
};

declare function form:gen-pic-selector ( $pid as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in fn:collection($globals:projects-uri)/Project[Id eq $pid]/Information/Beneficiaries/(Coordinator | Partner)
      let $n := $p/Name
      order by $n ascending
      return
        <Name id="{$p/PIC/text()}">{replace($n,' ','\\ ')}{'::'}{$p/PIC/text()}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a project Acronym
   ======================================================================
:)
declare function form:gen-acronym-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('acronym', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" param="select2_minimumInputLength=2;{form:setup-select2($params)}"/>
    else
      let $ids := 
        string-join(
          distinct-values(
            for $acro in fn:collection($globals:projects-uri)//Acronym
            order by $acro ascending
            return
              replace($acro,' ','\\ ')
          ),
          ' ')
      return (
          cache:update('acronym',$lang, $ids, ()),
          <xt:use types="choice" values="{$ids}" param="select2_minimumInputLength=2;{form:setup-select2($params)}"/>
          )
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting an enterprise
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   ======================================================================
:)
declare function form:gen-beneficiary-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('beneficiary', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/I18n}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
    else
      let $keys :=
        for $c in fn:collection($globals:projects-uri)//Project/Information/Beneficiaries/(Coordinator|Partner)
        let $n := $c/Name
        let $sat := $c/Address/Town
        order by $n ascending
        return
          concat(replace($n,' ','\\ '), if ($sat) then concat('::', replace($sat,' ','\\ ')) else ())
      return
        let $names := string-join(distinct-values($keys), ' ')
        return (
          cache:update('beneficiary',$lang, "", $names),
          <xt:use types="choice" values="{$names}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
          )
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting an enterprise
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   DEPRECATED
   ======================================================================
:)
declare function form:gen-beneficiary-selector-BIS ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('beneficiary', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" i18n="{$inCache/I18n}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
    else
      let $pairs :=
          for $ref in distinct-values(fn:collection($globals:projects-uri)//Project/Information/Beneficiaries/(Coordinator|Partner)/PIC)
          let $p := fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[Id eq $ref]
          let $n := $p/Name
          order by $n ascending
          return
             <Name id="{$p/Id/text()}">{replace($n,' ','\\ ')}{if ($p/Address/Town/text()) then concat('::', replace($p/Address/Town,' ','\\ ')) else ()}</Name>
      return
        let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
        let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
        return (
          cache:update('beneficiary',$lang, $ids, $names),
          <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
          )
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting an enterprise
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   ======================================================================
:)
declare function form:gen-enterprise-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('enterprise', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" i18n="{$inCache/I18n}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
    else
      let $pairs :=
          for $p in fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[not(@EnterpriseId)]
          let $n := $p/Name
          order by $n ascending
          return
             <Name id="{$p/Id/text()}">{replace($n,' ','\\ ')}{if ($p/Address/Town/text()) then concat('::', replace($p/Address/Town,' ','\\ ')) else ()}</Name>
      return
        let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
        let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
        return (
          cache:update('enterprise',$lang, $ids, $names),
          <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
          )
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting an enterprise town
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   ======================================================================
:)
declare function form:gen-town-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('town', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" param="{form:setup-select2($params)}"/>
    else
      let $towns :=
        for $t in distinct-values ((fn:doc($globals:enterprises-uri)//Enterprise[not(@EnterpriseId)]/Address/Town/text()))
        order by $t ascending
        return
          replace($t,' ','\\ ')
      return
        let $ids := string-join($towns, ' ')
        return (
          cache:update('town',$lang, $ids, ()),
          <xt:use types="choice" values="{$ids}" param="{form:setup-select2($params)}"/>
          )
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting an activity type
   DEPRECATED (service x phase have been totally decoupled in search)
   ======================================================================
:)
declare function form:gen-activity-type-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('ActivityTypes', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" i18n="{$inCache/I18n}" param="{form:setup-select2($params)}"/>
    else
      let $pairs :=
          for $p in fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/ActivityTypes/ActivityType
          let $n := $p/Name
          return
             <Name id="{$p/Id/text()}">{(replace($n,' ','\\ '))}</Name>
      return
        let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
        let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
        return (
          cache:update('ActivityTypes',$lang, $ids, $names),
          <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
          )
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a person's role
   ======================================================================
:)
declare function form:gen-role-selector ( $lang as xs:string, $params as xs:string ) as element() {
let $pairs :=
      for $p in fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/Functions/Function
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
   Generates XTiger XML 'choice' element for selecting a service
   ======================================================================
:)
declare function form:gen-service-selector ( $lang as xs:string, $params as xs:string ) as element() {
let $pairs :=
      for $p in fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/Services/Service
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
   Generates XTiger XML 'choice' element for selecting a  Case Impact (Vecteur d'innovation)
   TODO: 
   - caching
   - use Selector / Group generic structure with a gen-selector-for( $name, $group, $lang, $params) generic function
   ======================================================================
:)
declare function form:gen-challenges-selector-for  ( $root as xs:string, $lang as xs:string, $params as xs:string ) as element() {
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
   Generates XTiger XML 'choice' element for selecting a country
   FIXME: integrate caching into gen-selector-for and replace with gen-selector-for
   DEPRECATED
   ======================================================================
:)
declare function form:gen-country-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('Countries', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" i18n="{$inCache/I18n}" param="{form:setup-select2($params)}"/>
    else
      let $sel := form:gen-selector-for( 'Countries', $lang, $params )
      return (
        cache:update('Countries', $lang, string($sel/@values), string($sel/@i18n)),
        $sel
        )
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
   Generates XTiger XML 'choice' element for a given selector as a drop down list
   Used for EEN Entities only (Regions)
   ======================================================================
:)
declare function form:gen-selector-for-regional-entities ( $lang as xs:string, $params as xs:string ) as element() {
  let $defs := <Selector Name="RegionalEntities" Value="Id" Label="Label" Test="EEN Entities">{ fn:collection($globals:regions-uri)/Region }</Selector>
  let $concat := if (starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs[1]/@Label, 'V+') else string($defs[1]/@Label)
  let $value := $defs[1]/@Value
  return
     let $pairs :=
        for $p in $defs/Region
        let $v := $p/*[local-name(.) eq $value]/text()
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/*[local-name(.) eq $label]
        order by number($p/Id/text()) ascending
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
:)declare function form:gen-selector-for-regional-entities ( $lang as xs:string, $params as xs:string, $label as xs:string ) as element() {
  let $defs := <Selector Name="RegionalEntities" Value="Id" Label="Label" Test="EEN Entities">{fn:collection($globals:regions-uri)/Region}</Selector>
  return
     let $pairs :=
        for $p in $defs/Region
        let $v := $p/*[local-name(.) eq string($defs/@Value)]/text()
        let $l := $p/*[local-name(.) eq $label]
        order by number($p/Id/text()) ascending
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for a given selector as a drop down list
   TODO:
   - caching
   ======================================================================
:)
declare function form:gen-selector-for ( $name as xs:string+, $lang as xs:string, $params as xs:string ) as element() {
  let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name = $name]
  let $concat := if (starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs[1]/@Label, 'V+') else string($defs[1]/@Label)
  let $value := $defs[1]/@Value
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := $p/*[local-name(.) eq $value]/text()
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
:)declare function form:gen-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string, $label as xs:string ) as element() {
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
   Generates selector with list of all KAMs (for /Stage request)
   For optimization purposes it only generates KAM who actually manage a Case
   ======================================================================
:)
declare function form:gen-kam-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $ref in distinct-values(fn:collection($globals:projects-uri)//AccountManagerRef/text())
      let $p := fn:collection($globals:persons-uri)//Person[Id eq $ref]
      let $fn := $p/Name/FirstName
      let $ln := $p/Name/LastName
      order by $ln ascending
      return
        <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}</Name>
  return
    if (count($pairs) > 0) then
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_complement=town;{form:setup-select2($params)}"/>
    else
      <xt:use types="constant" param="noxml=true;class=uneditable-input span2">None assigned yet</xt:use>
};

(: ======================================================================
   Non optimized version
   ======================================================================
:)
declare function form:gen-kam-selector-OFF ( $lang as xs:string, $params as xs:string ) as element() {
  let $role-ref := access:get-function-ref-for-role('kam')
  let $pairs :=
      for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[(FunctionRef eq $role-ref)]]
      let $fn := $p/Name/FirstName
      let $ln := $p/Name/LastName
      order by $ln ascending
      return
        <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}</Name>
  return
    if (count($pairs) > 0) then
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
    else
      <xt:use types="constant" param="noxml=true;class=uneditable-input span2">None assigned yet</xt:use>
};

(: ======================================================================
   Internal utility for form:gen-kam-for-case-selector to handle special 
   case where KAM is no more registered for the EEN Entity of the Case !
   ======================================================================
:)
declare function local:gen-legacy-kam-name( $ref as xs:string, $region-name as xs:string? ) {
  let $p := fn:collection($globals:persons-uri)//Person[Id = $ref]
  let $name := 
    if ($p) then
      concat($p/Name/LastName, ' ', $p/Name/FirstName)
    else
      display:noref($ref, 'en')
  return
    replace(concat($name, '::no longer registered as KAM for ', $region-name), ' ', '\\ ')
};

(: ======================================================================
   Generates selector with list of all KAMs for a given Case with a given regional entity  (for /Stage request)
   The legacy KAM if any is included just in case s/he is no more registered as KAM for the entity !
   ======================================================================
:)
declare function form:gen-kam-for-case-selector ( $case as element()?, $lang as xs:string, $params as xs:string, $legacy as element()? ) as element() {
  let $region := $case/ManagingEntity/RegionalEntityRef
  return
    if ($region) then 
      let $region-ref := $case/ManagingEntity/RegionalEntityRef/text()
      let $region-name := display:gen-name-for-regional-entities( $region, $lang )
      let $role-ref := access:get-function-ref-for-role('kam')
      let $pairs :=
          for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[(FunctionRef eq $role-ref) and (RegionalEntityRef eq $region-ref)]]
          let $fn := $p/Name/FirstName
          let $ln := $p/Name/LastName
          order by $ln ascending
          return
            <Name id="{$p/Id/text()}">{ replace(concat($ln,' ',$fn, '::', $region-name), ' ', '\\ ') }</Name>
      return
        if ($legacy and (count($pairs) = 0 )) then
            <xt:use types="choice" values="{$legacy/text()}" i18n="{ local:gen-legacy-kam-name($legacy, $region-name) }"
                    param="select2_complement=town;{form:setup-select2($params)}"/>
        else
          if (count($pairs) > 0) then
            let $ids := for $n in $pairs return string($n/@id) (: FLWOR to defeat document ordering :)
            let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
            let $xtra-id := if ($legacy and not($legacy/text() = $ids)) then concat(' ', $legacy/text()) else ''
            let $xtra-name := if ($legacy and not($legacy/text() = $ids)) then 
                                concat(' ', local:gen-legacy-kam-name($legacy, $region-name))
                              else 
                                ''
            return
              <xt:use types="choice" values="{ string-join($ids, ' ') }{ $xtra-id }" i18n="{ $names }{ $xtra-name }"
                      param="select2_complement=town;{form:setup-select2($params)}"/>
        else
          <xt:use types="constant" param="noxml=true;class=uneditable-input span"
            >No KAM profile for { display:gen-name-for-regional-entities( $region, $lang) } in database</xt:use>
    else
      form:gen-kam-selector($lang, $params)
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a workflow status
   DEPRECATED: to be removed used in stats
   ======================================================================
:)
declare function form:gen-workflow-status-selector ( $workflow as xs:string, $lang as xs:string, $params as xs:string ) as element() {

  let $pairs :=
      for $p in fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/WorkflowStatus[@Name = $workflow]/Status[not(@Deprecated)]
      let $n := $p/Name
      return
         <Name id="{$p/Id/text()}">{(replace($n,' ','\\ '))}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates a 'choice2' selector with JSON menu definition
   Notes : only applies to two level selection (NOGA and Markets)
   TODO: cache
   ======================================================================
:)
declare function form:gen-json-selector-for ( $name as xs:string+, $lang as xs:string, $params as xs:string ) as element() {
  let $json := 
    <json>
      {
      for $g in fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name = $name]/Group
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
  (: trick because of JSON serialization bug, assumes at list 10 chars 
  let $dedouble := concat(substring-before($res, concat("}", substring($res, 1, 10))), "}") :)
  let $unfilter := replace($res, '"_', '"')
  return
   <xt:use types='choice2v2' param="{$params}" values='{ $unfilter }'/>
};

declare function form:gen-json-3selector-for ( $name as xs:string+, $lang as xs:string, $params as xs:string ) as element() {
  let $json := 
    <json>
      {
      for $g in fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name = $name]/Group
      return
        element { concat('_', $g/Code/text()) }
        {(
        element { '__label' } { $g/Name/text() },
        for $g2 in $g/Selector/Group
        return
          element { concat('_', $g2/Code/text()) }
          {(
            element { '__label' } { $g2/Name/text() },
              for $o in $g2//Option
              return
                element { concat('_', $o/Code/text()) } {
                  $o/Name/text()
                }
          )}
        )}
      }
    </json>
  let $res := util:serialize($json, 'method=json')
  (: trick because of JSON serialization bug, assumes at list 10 chars :)
  (:let $dedouble := concat(substring-before($res, concat("}", substring($res, 1, 10))), "}"):)
  let $unfilter := replace($res, '"_', '"')
  return
    <xt:use types='choice3v2' param="{$params}" values='{ $unfilter }'/>
};

(: ======================================================================
   Generate the selector for Nuts code from all the nuts used in database
   TODO: use a 'choice2' selector ?
   ======================================================================
:)
declare function form:gen-selector-for-nuts ( $lang as xs:string, $params as xs:string, $class as xs:string? ) as element() {
  let $nuts := distinct-values(
    fn:collection($globals:regions-uri)//Nuts/text()
    )
  return
    if (count($nuts) > 0) then
      let $ids := string-join($nuts, ' ')
      return
        <xt:use types="choice" values="{$ids}" param="{form:setup-select2($params)}"/>
    else
      <xt:use types="constant" param="noxml=true;class=uneditable-input {$class}">Not available</xt:use>
};

(: ======================================================================
   Generates selector for creation years 
   ======================================================================
:)
declare function form:gen-creation-year-selector ( ) as element() {
  let $years := 
    for $y in distinct-values(fn:collection($globals:projects-uri)//CreationYear)
    where matches($y, "^\d{4}$")
    order by $y descending
    return $y
  return
    <xt:use types="choice" values="{ string-join($years, ' ') }" param="select2_dropdownAutoWidth=on;select2_width=off;class=year a-control;filter=optional select2;multiple=no"/>
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
