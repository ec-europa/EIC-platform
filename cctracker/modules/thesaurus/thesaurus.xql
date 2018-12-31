xquery version "1.0";
(: --------------------------------------
   Experimental localization

   Author: Stéphane Sire <s.sire@oppidoc.fr>

   Utility to allow simple and double entries lists editing to localize global-information.xml

   The algorithm uses the 'fr' version as a referential, hence the 'de' version must be aligned
   on the same keys, any extra keys will not be exported.

   April 2014 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace th = "http://platinn.ch/cocahing/thesaurus";

declare option exist:serialize "method=xml media-type=application/xml";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace cache = "http://oppidoc.com/ns/cctracker/cache" at "../../lib/cache.xqm";

declare variable $th:simple-lists :=
  <th:SingleEntryLists>
    <th:List id="1" Root="Services" Item="Service" Key="Id" Label="Name"/>
    <th:List id="2" Root="Cantons" Item="Canton" Key="CantonShortName" Label="CantonName"/>    
    <th:List id="3" Root="CantonalAntennas" Item="CantonalAntenna" Key="CantonShortName" Label="Name"/>
    <th:List id="4" Root="Functions" Item="Function" Key="Id" Label="Name"/>
    <th:List id="5" Root="Sizes" Item="Size" Key="Id" Label="Name"/>
    <th:List id="6" Root="Markets" Item="MarketValue" Key="Code" Label="Name"/>
    <th:List id="7" Root="CaseContext" Item="ContextValue" Key="Id" Label="Name"/>
    <th:List id="8" Root="ActivityStatus" Item="Status" Key="Id" Label="Name"/>
    <th:List id="9" Root="ActivityPhases" Item="Phase" Key="Id" Label="Name"/>
    <th:List id="10" Root="ActivityTypes" Item="ActivityType" Key="Id" Label="Name"/>
    <th:List id="11" Root="ContactSources" Item="ContactSource" Key="Id" Label="Name"/>
    <th:List id="12" Root="PartnerTypes" Item="PartnerType" Key="Id" Label="Name"/>
    <th:List id="13" Root="PartnerRoles" Item="PartnerRole" Key="Id" Label="Name"/>
    <th:List id="14" Root="FundingSources" Item="FundingSource" Key="Id" Label="Name"/>
    <th:List id="15" Root="ServiceResponsibleOpinions" Item="ServiceResponsibleOpinion" Key="Id" Label="Name"/>
    <th:List id="16" Root="CantonalAntennaOpinions" Item="CantonalAntennaOpinion" Key="Id" Label="Name"/>
    <th:List id="17" Root="DecisionMakingAuthorities" Item="DecisionMakingAuthority" Key="Id" Label="Name"/>
    <th:List id="18" Root="CommunicationAdvices" Item="CommunicationAdvice" Key="Id" Label="Name"/>
    <th:List id="19" Root="FinalReportOpinions" Item="FinalReportOpinion" Key="Id" Label="Name"/>
    <th:List id="20" Root="ProjectEffects" Item="ProjectEffect" Key="Id" Label="Name"/>
    <!--<th:List id="21" Root="SatisfactionLevel" Item="SatisfactionCriteria" Key="Id" Label="Name"/>-->
  </th:SingleEntryLists>;

declare variable $th:double-lists :=
  <th:DoubleEntryLists>
    <th:List id="1" Root="CaseImpact" Item="Section" Key="Id" Label="SectionName" >
      <th:List Root="SubSections" Item="SubSection" Key="Id" Label="SubSectionName"/>
    </th:List>
    <th:List id="2" Root="NOGA-Classification" Item="Section" Key="Code" Label="Name" >
      <th:List Root="Divisions" Item="Division" Key="Code" Label="Name"/>
    </th:List>
  </th:DoubleEntryLists>;

(: ======================================================================
   Returns the root element of a simple list in Global Information with the 'fr' referential
   $spec must come from $th:simple-lists
   ======================================================================
:)
declare function local:get-simple-list-root( $spec as element(), $lang as xs:string ) {
  let $defs := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang=$lang]/*[local-name(.) = string($spec/@Root)]
(:  let $defs := fn:doc('/db/debug/debug.xml')/Debug/Description[@Lang=$lang]/*[local-name(.) = string($spec/@Root)]:)
  return
      $defs
};

(: ======================================================================
   Returns the root element of a double list in Global Information with the 'fr' referential
   Also adapts the structure of CaseImpact which has one extra level
   $spec must come from $th:double-lists
   ======================================================================
:)
declare function local:get-double-list-root( $spec as element(), $lang as xs:string ) {
  let $defs := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang=$lang]/*[local-name(.) = string($spec/@Root)]
(:  let $defs := fn:doc('/db/debug/debug.xml')/Debug/Description[@Lang=$lang]/*[local-name(.) = string($spec/@Root)]:)
  return
    if ($spec/@Root = 'CaseImpact') then (: exception for CaseImpact :)
      $defs/Sections
    else
      $defs
};

(: ======================================================================
   Turns $root simple list (raw Global Information sub-tree) into a generic simple list
   Note this is also called when generating a generic double list
   ======================================================================
:)
declare function local:gen-simple-list-I( $root as element()?, $spec as element() ) as element()
{
  <th:List>
    {
    for $item in $root/*[local-name(.) = string($spec/@Item)]
    let $item-de := $root/ancestor::Description[@Lang='fr']/parent::*/Description[@Lang='de']/*[local-name(.) = string($spec/@Root)]/*[local-name(.) = string($spec/@Item)][*[local-name(.) = string($spec/@Key)]/text() = $item/*[local-name(.) = string($spec/@Key)]]
    let $item-en := $root/ancestor::Description[@Lang='fr']/parent::*/Description[@Lang='en']/*[local-name(.) = string($spec/@Root)]/*[local-name(.) = string($spec/@Item)][*[local-name(.) = string($spec/@Key)]/text() = $item/*[local-name(.) = string($spec/@Key)]]    
    return
      <th:Item>
        <th:Key>{$item/*[local-name(.) = string($spec/@Key)]/text()}</th:Key>
        <th:Label Lang="fr">{$item/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        {
        if ($item-de) then
          <th:Label Lang="de">{$item-de/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        else
          ()
        }
        {
        if ($item-en) then
          <th:Label Lang="en">{$item-en/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        else
          ()
        }        
      </th:Item>
    }
  </th:List>
};

(: ======================================================================
   Same as local:gen-simple-list-I but in double list context
   ======================================================================
:)
declare function local:gen-simple-list-II( $root as element()?, $root-de as element()?, $root-en as element()?, $spec as element() ) as element()
{
  <th:List>
    {
    for $item in $root/*[local-name(.) = string($spec/@Item)]
    let $item-de := $root-de/*[local-name(.) = string($spec/@Item)][*[local-name(.) = string($spec/@Key)]/text() = $item/*[local-name(.) = string($spec/@Key)]/text()]
    let $item-en := $root-en/*[local-name(.) = string($spec/@Item)][*[local-name(.) = string($spec/@Key)]/text() = $item/*[local-name(.) = string($spec/@Key)]/text()]    
    return
      <th:Item>
        <th:Key>{$item/*[local-name(.) = string($spec/@Key)]/text()}</th:Key>
        <th:Label Lang="fr">{$item/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        {
        if ($item-de) then
          <th:Label Lang="de">{$item-de/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        else
          ()
        }
        {
        if ($item-en) then
          <th:Label Lang="en">{$item-en/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        else
          ()
        }
      </th:Item>
    }
  </th:List>
};

(: ======================================================================
   Genreates simple entry list data model for editing
   ======================================================================
:)
declare function local:gen-simple-data-for-editing( $id as xs:string )
{
  let $spec := $th:simple-lists/th:List[@id = $id]
  let $list := local:get-simple-list-root($spec, 'fr') (: 'fr' as referential :)
  return
    local:gen-simple-list-I($list, $spec)
};

(: ======================================================================
   Transforms a simple list generic representation into an XTiger XML template
   Current list content becomes default content
   ======================================================================
:)
declare function local:gen-template-for-editing( $data as element() ) as element()
{
  <html xmlns="http://www.w3.org/1999/xhtml" xmlns:xt="http://ns.inria.org/xtiger">
    <xt:head version="1.1" templateVersion="1.0" label="SimpleList">
      {
      for $item in $data/th:Item
      return
        <xt:component name="t_item_{$item/th:Key}">
          <tr>
            <td><xt:use types="constant" label="Key">{$item/th:Key/text()}</xt:use></td>
            <td><xt:use types="text" param="type=textarea;shape=parent" label="Label-FR">{$item/th:Label[@Lang = 'fr']/text()}</xt:use></td>
            <td>
            {
            if ($item/th:Label[@Lang = 'de']) then
              <xt:use types="text"  param="type=textarea;shape=parent" label="Label-DE">{$item/th:Label[@Lang = 'de']/text()}</xt:use>
            else
              "---"
            }
            </td>
            <td>
            {
            if ($item/th:Label[@Lang = 'en']) then
              <xt:use types="text"  param="type=textarea;shape=parent" label="Label-EN">{$item/th:Label[@Lang = 'en']/text()}</xt:use>
            else
              "---"
            }
            </td>
          </tr>
        </xt:component>
      }
    </xt:head>
    <body>
      {
      if (count($data/th:Item) = 0) then
        <p>Pas de données à éditer dans la base de données</p>
      else
        <table class="table table-bordered">
          <thead>
            <tr>
              <th style="width:100px">Clef</th>
              <th>Label (fr)</th>
              <th>Label (de)</th>
              <th>Label (en)</th>
            </tr>
          </thead>
          <tbody>
          {
          for $item in $data/th:Item
          return
            <xt:use types="t_item_{$item/th:Key}" label="Item"/>
          }
          </tbody>
        </table>
      }
    </body>
  </html>
};

(: ======================================================================
   Generates double entry list data model for editing
   FIXME: generate multiple Labels <Label Lang='fr'> and <Label Lang='de'>
   ======================================================================
:)
declare function local:gen-double-list( $root as element()?, $spec as element() ) as element()
{
  <th:List>
    {
    for $item in $root/*[local-name(.) = string($spec/@Item)]
    let $item-de := $root/ancestor::Description[@Lang='fr']/parent::*/Description[@Lang='de']/*[local-name(.) = string($spec/@Root)]//*[local-name(.) = string($spec/@Item)][*[local-name(.) = string($spec/@Key)]/text() = $item/*[local-name(.) = string($spec/@Key)]]
    let $item-en := $root/ancestor::Description[@Lang='fr']/parent::*/Description[@Lang='en']/*[local-name(.) = string($spec/@Root)]//*[local-name(.) = string($spec/@Item)][*[local-name(.) = string($spec/@Key)]/text() = $item/*[local-name(.) = string($spec/@Key)]]    
    return
      <th:Item>
        <th:Key>{$item/*[local-name(.) = string($spec/@Key)]/text()}</th:Key>
        <th:Label Lang="fr">{$item/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        {
        if ($item-de) then
          <th:Label Lang="de">{$item-de/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        else
          ()
        }
        {
        if ($item-en) then
          <th:Label Lang="en">{$item-en/*[local-name(.) = string($spec/@Label)]/text()}</th:Label>
        else
          ()
        }
        { local:gen-simple-list-II(
            $item/*[local-name(.) = string($spec/th:List/@Root)],
            $item-de/*[local-name(.) = string($spec/th:List/@Root)],
            $item-en/*[local-name(.) = string($spec/th:List/@Root)],
            $spec/th:List)
        }
      </th:Item>
    }
  </th:List>
};

(: ======================================================================
   Extracts a double list from the database and transforms it into
   a generic representation suitable for transformation to an XTiger template
   FIXME: generate multiple Labels <Label Lang='fr'> and <Label Lang='de'>
   ======================================================================
:)
declare function local:gen-double-data-for-editing( $id as xs:string ) {
  let $spec := $th:double-lists/th:List[@id = $id]
  return
    local:gen-double-list(local:get-double-list-root($spec, 'fr'), $spec)  (: 'fr' as referential :)
};

(: ======================================================================
   Transforms a double list generic representation into an XTiger XML template
   Current lists content becomes default content
   ======================================================================
:)
declare function local:gen-double-template-for-editing( $data as element() ) as element()
{
  <html xmlns="http://www.w3.org/1999/xhtml" xmlns:xt="http://ns.inria.org/xtiger">
    <xt:head version="1.1" templateVersion="1.0" label="DoubleList">
      {
      for $item in $data/th:Item
      return (
        <xt:component name="t_list_{$item/th:Key}">
          <table class="table table-bordered">
            <thead>
              <tr>
                <th style="width:50px">Clef</th>
                <th style="width:226px">Label (fr)</th>
                <th style="width:226px">Label (de)</th>
                <th style="width:226px">Label (en)</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><xt:use types="constant" label="Key">{$item/th:Key/text()}</xt:use></td>
                <td><xt:use types="text" param="type=textarea;shape=parent-20px" label="Label-FR">{$item/th:Label[@Lang = 'fr']/text()}</xt:use></td>
                <td>
                {
                if ($item/th:Label[@Lang = 'de']) then
                  <xt:use types="text" param="type=textarea;shape=parent-20px" label="Label-DE">{$item/th:Label[@Lang = 'de']/text()}</xt:use>
                else
                  "---"
                }
                </td>
                <td>
                {
                if ($item/th:Label[@Lang = 'en']) then
                  <xt:use types="text" param="type=textarea;shape=parent-20px" label="Label-EN">{$item/th:Label[@Lang = 'en']/text()}</xt:use>
                else
                  "---"
                }
                </td>
              </tr>
            </tbody>
          </table>
          <xt:use types="t_content_{$item/th:Key}" label="List"/>
        </xt:component>,
        <xt:component name="t_content_{$item/th:Key}">
          <table class="table table-bordered">
            <tbody>
            {
            for $subitem in $item/th:List/th:Item
            return
                  <xt:use types="t_item_{$item/th:Key}_{$subitem/th:Key}" label="Item"/>
            }
            </tbody>
          </table>
        </xt:component>,
        for $subitem in $item/th:List/th:Item
        return
          <xt:component name="t_item_{$item/th:Key}_{$subitem/th:Key}">
            <tr>
              <td style="width:50px"><xt:use types="constant" label="Key">{$subitem/th:Key/text()}</xt:use></td>
              <td style="width:226px"><xt:use types="text" param="type=textarea;shape=parent-20px"  label="Label-FR">{$subitem/th:Label[@Lang = 'fr']/text()}</xt:use></td>
              <td style="width:226px">
              {
              if ($item/th:Label[@Lang = 'de']) then
                <xt:use types="text" param="type=textarea;shape=parent-20px"  label="Label-DE">{$subitem/th:Label[@Lang = 'de']/text()}</xt:use>
                else
                "---"
              }
              </td>
              <td style="width:226px">
              {
              if ($item/th:Label[@Lang = 'en']) then
                <xt:use types="text" param="type=textarea;shape=parent-20px"  label="Label-EN">{$subitem/th:Label[@Lang = 'en']/text()}</xt:use>
                else
                "---"
              }
              </td>
            </tr>
          </xt:component>
      )
      }
    </xt:head>
    <body>
      {
      if (count($data/th:Item) = 0) then
        <p>Pas de données à éditer dans la base de données</p>
      else
        for $item in $data/th:Item
        return (
          <xt:use types="t_list_{$item/th:Key}" label="Item"/>,
          <br/>
          )
      }
    </body>
  </html>
};

(: ======================================================================
   Updates a simple list in Global Information in a given lang (Upper case)
   (also used to update simple lists inside double lists)
   ======================================================================
:)
declare function local:update-simple-list(
  $spec as element(),
  $list as element(),
  $data as element(),
  $ulang as xs:string
  )
{
  for $item in $list/*[local-name(.) = string($spec/@Item)]
  let $key := $item/*[local-name(.) = string($spec/@Key)]
  let $label := $item/*[local-name(.) = string($spec/@Label)]
  let $new-label := $data/Item[Key = $key/text()]/*[local-name(.) = concat('Label-', $ulang)]
  where not(empty($new-label)) and ($new-label ne $label)
  return
    update value $item/*[local-name(.) = string($spec/@Label)] with $new-label/text()
};

(: ======================================================================
   Updates a simple list in Global Information from submitted data
   in a given lang (stub function)
   ======================================================================
:)
declare function local:update-simple-data(
  $id as xs:string,
  $lang as xs:string,
  $data as element()
  )
{
  let $spec := $th:simple-lists/th:List[@id = $id]
  let $ulang := upper-case($lang)
  let $list := local:get-simple-list-root($spec, $lang)
  return
    if ($list) then (
      cache:invalidate(string($spec/@Root), $lang),
      local:update-simple-list($spec, $list, $data, $ulang)
      )
    else
     ()

};

(: ======================================================================
   Updates a double list in Global Information from submitted data in a given lang
   ======================================================================
:)
declare function local:update-double-data(
  $id as xs:string,
  $lang as xs:string,
  $data as element()
  )
{
  let $spec := $th:double-lists/th:List[@id = $id]
  let $ulang := upper-case($lang)
  let $list := local:get-double-list-root($spec, $lang)
  return
    if ($list) then (
      cache:invalidate(string($spec/@Root), $lang),
      for $item in $list/*[local-name(.) = string($spec/@Item)]
      let $key := $item/*[local-name(.) = string($spec/@Key)]
      let $label := $item/*[local-name(.) = string($spec/@Label)]
      let $new-label := $data/Item[Key = $key/text()]/*[local-name(.) = concat('Label-', $ulang)]
      return (
        if (not(empty($new-label)) and ($new-label ne $label)) then
          update value $item/*[local-name(.) = string($spec/@Label)] with $new-label/text()
        else
          (),
        local:update-simple-list($spec/th:List,
          $item/*[local-name(.) = string($spec/th:List/@Root)],
          $data/Item[Key = $key/text()]/List,
          $ulang)
        )
      )
    else
      ()
};

let $m := request:get-method()
let $id := request:get-parameter('id', ())
return
  if ($m = 'POST') then
    let $data := oppidum:get-data()
    return (
        if (local-name($data) = 'SimpleList') then (
          if (count($data//Label-FR) > 0) then local:update-simple-data($id, 'fr', $data) else (),
          if (count($data//Label-DE) > 0) then local:update-simple-data($id, 'de', $data) else (),
          if (count($data//Label-EN) > 0) then local:update-simple-data($id, 'en', $data) else ()
          )
        else ( (: assumes 'DoubleList' :)
          if (count($data//Label-FR) > 0) then local:update-double-data($id, 'fr', $data) else (),
          if (count($data//Label-DE) > 0) then local:update-double-data($id, 'de', $data) else (),
          if (count($data//Label-FR) > 0) then local:update-double-data($id, 'en', $data) else ()
          ),
      ajax:report-success('ACTION-UPDATE-SUCCESS', ())
      )[last()]
  else (: assumes GET :)
    let $template := request:get-parameter('template', ())
    return
      if ($template eq '1') then (: XTiger template generation for modal window :)
        local:gen-template-for-editing(
          local:gen-simple-data-for-editing($id)
        )
      else if ($template eq '2') then (: XTiger template generation for modal window :)
        local:gen-double-template-for-editing(
          local:gen-double-data-for-editing($id)
        )
      else (: List selection menu generation for tab pane :)
        <div id="results" class="row-fluid">
          <p style="color:red">DEPRECATED - All this section will be released later</p>
          <h1>Thesaurus</h1>
          <p>Click on a selectors name below to edit the corresponding labels. This will change all the corresponding selector drop down lists in the application.</p>
          <div class="span5">
            <ul class="unstyled">
              {
              for $l in $th:simple-lists/th:List
              return
                <li><a href="#" data-controller="management/thesaurus?id={$l/@id}&amp;template=1">{string($l/@Root)}</a></li>
              }
            </ul>
          </div>
          <div class="span5">
            <ul class="unstyled">
            {
            for $l in $th:double-lists/th:List
            return
              <li><a href="#" data-controller="management/thesaurus?id={$l/@id}&amp;template=2">{string($l/@Root)}</a></li>
            }
            </ul>
          </div>
          <div class="span10" style="margin-left:0">
            <p>Les entrées marquées --- dans les listes ne sont pas définies, il faut qu'un administrateur de la base de donnée les crée d'abord dans la ressource <tt>global-information.xml</tt>.</p>
          </div>
        </div>
