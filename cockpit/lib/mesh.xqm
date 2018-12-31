xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   Highly experimental code to generate an XTiger template from an XML document

   Initially developped to edit Event meta-data files

   Limitations:
   - @Selector attribute has a special meaning and will not be edited
   - attributes in data model MUST be associated with a pre-generated 
     selector in the selectors map (using version of mesh:transform
     that takes a map for pre-generated selectors)
   - only terminal elements can have some attributes (tested with max
     1 attribute)

   TODO:
  - remove @Label and @Selector special meaning attributes

   September 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace mesh = "http://oppidoc.com/ns/mesh";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../xcm/lib/form.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "display.xqm";

declare function local:camel-case-to-words($tag-name as xs:string) {
  concat(substring($tag-name,1,1),
           replace(substring($tag-name,2),'(\p{Lu})',
                      concat(' ', '$1')))
};

(: ======================================================================
   Generate screen label for $node field
   ====================================================================== 
:)
declare function mesh:labelize($node as node(), $selectors as map()?) as xs:string {
  if ($node/@Label) then
    $node/@Label
  else
    let $key := local-name($node)
    let $alt-key := concat(local-name($node/parent::*), $key) (: contextualized key :)
    let $dico := if (exists($selectors)) then map:get($selectors, '#labels') else ()
    return
      if (exists($dico) and (map:get($dico, $key) or map:get($dico, $alt-key))) then
        if (map:contains($dico, $key)) then
          map:get($dico, $key)
        else
          map:get($dico, $alt-key)
      else
        let $name := local:camel-case-to-words($key)
        return
          if ($node instance of attribute()) then
            concat('@', $name)
          else
            $name
};

declare function mesh:guess-type($node as node()) as xs:string {
    if (local-name($node) = ('From', 'To') or fn:matches($node/node(),'[0-9]{4}-[0-9]{2}-[0-9]{2}')) then
        'date'
    else if (exists($node/Text)) then
        'multi'
    else (: fallback :)
        'text'
};

(: ======================================================================
   Actually attributes reaching that point will be turned to constant fields
   ====================================================================== 
:)
declare function mesh:build-field($node as node()) as element(xt:use) {
  if ($node instance of attribute()) then
    <xt:attribute types="constant" name="{local-name($node)}" param="class=span a-control uneditable-input" default="{ string($node) }"/>
  else
    let $type := mesh:guess-type($node)
    return
      <xt:use types="input">
      {
        if (some $a in $node/attribute::* satisfies local-name($a) ne 'Selector') then
          () (: label set on component wrapping attributes with node :)
        else
          attribute { 'label' } { local-name($node) },
        switch ($type)
        case "date" return attribute param {'type=date;date_region=en;date_format=ISO_8601;class=date;class=span a-control'}
        case "multi" return attribute param {'type=textarea;multilines=normal;class=sg-multitext span a-control'}
        case "text" return attribute param {'class=span a-control'}
        default return attribute param {'class=span a-control'},
        switch ($type)
        case "date" return display:gen-display-date($node/node(), 'en')
        case "multi" return string-join($node/Text, '&#10;&#10;')
        default return $node/node()
      }
      </xt:use>
};

declare function mesh:gen-field($node as element()) as element(xt:use) {
  let $selector :=
    if ($node/@Selector) then
      let $sel := fn:collection($globals:global-info-uri)//Selector[@Name eq string($node/@Selector)]
      return
        if ($sel) then
          $sel
        else
          ()
    else(: heuristic :)
      let $attr := string($node/@*[1])
      return
        if ($attr) then
          fn:collection($globals:global-info-uri)//Selector[Option/Value/text() eq $attr][1]
        else
          ()
  return
    if ($selector) then
      let $xtuse := form:gen-selector-for($selector/@Name, 'en', '')
      return
        (: heuristic in case default value is coded by a @WorkflowId !!! :)
        <xt:use label="{ local-name($node) }">
          {
          $xtuse/(@*|*),
          (: FIXME: could we use $node/@* ? :)
          if ($node/@WorkflowId and contains($xtuse/@values, $node/@WorkflowId)) then
            string($node/@WorkflowId)
          else
            $node/text()
          }
        </xt:use>
    else
      mesh:build-field($node)
};

(: DEPRECATED version w/o selectors map :)
declare function mesh:field-meshify($node as element()) as item()* {
  <div class="span12">
    <div class="control-group">
      <label class="control-label a-gap3">{ mesh:labelize($node, ()) }</label>
    </div>
    <div class="controls">{ mesh:gen-field($node) }</div>
  </div>
};

(: DEPRECATED version w/o selectors map :)
declare function mesh:transform($nodes as element()*) as item()* {
  for $n in $nodes
  let $c := $n/element()
  return 
    if ($n[not(child::element())]) then
      mesh:field-meshify($n)
    else
      <xt:component name="{local-name($n)}">{ mesh:transform($c) }</xt:component>
};

(: ======================================================================
   Create a component for a node to generate a label
   Pass-through hidden field (used to hide Id)
   ====================================================================== 
:)
declare function mesh:modularize($node as node()) as item()* {
  element xt:component {
    $node/@*,
    $node/(div|xhtml:div|hide),
    for $c in $node/xt:component
    let $cn := $c/@name
    return
      <xt:use label="{$cn}" types="{$cn}"/>
  }
};

declare function mesh:compact($node as node()) as item()* {
  typeswitch ($node)
  case element(xt:component) return 
    if ($node/xt:component) then
    (
      mesh:modularize($node),
      for $c in $node/xt:component return mesh:compact($c)
    )
    else
      $node
  default return $node
};

declare function mesh:embedding($nodes as element(xt:component)*) as element(xt:component)* {
  for $node in $nodes
  let $cnt := count($node/xt:use)
  return
    <xt:component>
    {
      $node/@*,
      for $c in ($node/(div|xhtml:div|hide), $node/xt:use)
      return
      if (local-name($c) eq 'hide') then
        <div class="row-fluid" style="display:none" xmlns="http://www.w3.org/1999/xhtml">
          { $c/* }
        </div>
      else
        <div class="row-fluid" xmlns="http://www.w3.org/1999/xhtml">
        {
          if ($cnt ge 2 and name($c) eq 'xt:use') then 
            <h2>{ string($c/@label) }</h2>
          else 
            (),
          $c
        }
        </div>
    }
    </xt:component>
};

declare function mesh:gen-field($node as node(), $selectors as map()) as element() {
  let $tag := local-name($node)
  return
    if (map:contains($selectors, $tag)) then
      map:get($selectors, local-name($node))
    else
      mesh:build-field($node)
};

declare function mesh:field-meshify($node as node(), $selectors as map()) as item()* {
  <div class="span12" xmlns="http://www.w3.org/1999/xhtml">
    <div class="control-group">
      <label class="control-label a-gap">{ mesh:labelize($node, $selectors) }</label>
    </div>
    <div class="controls">{ mesh:gen-field($node, $selectors) }</div>
  </div>
};

(: ======================================================================
   XTiger mesh generator using a pre-computed set of selectors 
   to render editing field tagged with an available key
   ====================================================================== 
:)
declare function mesh:transform($nodes as element()*, $selectors as map()) as item()* {
  for $n in $nodes
  let $c := $n/element()
  return 
    if (local-name($n) eq 'Id') then (: keep as hidden Id - useful to Duplicate entity :)
      <hide>
        <xt:use types="constant" label="Id">{$n/text()}</xt:use>
      </hide>
    else if (some $a in $n/attribute::* satisfies local-name($a) ne 'Selector') then 
      (: skips DEPRECATD @Selector - element supposed to be terminal :)
      <xt:component name="{local-name($n)}">
        { 
        for $a in $n/attribute::*[local-name() ne 'Selector']
        return mesh:field-meshify($a, $selectors),
        mesh:field-meshify($n, $selectors)
      }
      </xt:component>
    else if ($n[not(child::element())] or $n/Text) then
      mesh:field-meshify($n, $selectors)
    else
      <xt:component name="{local-name($n)}">{ mesh:transform($c, $selectors) }</xt:component>
};

