xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   January 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xt = "http://ns.inria.org/xtiger";

declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo="http://exist-db.org/xquery/xslfo";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";

declare namespace request = "http://exist-db.org/xquery/request";
declare namespace session = "http://exist-db.org/xquery/session";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace util="http://exist-db.org/xquery/util";

declare namespace ms = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../oppidum/lib/util.xqm";
import module namespace skin = "http://oppidoc.com/oppidum/skin" at "../oppidum/lib/skin.xqm";
import module namespace epilogue = "http://oppidoc.com/oppidum/epilogue" at "../oppidum/lib/epilogue.xqm";
import module namespace partial = "http://oppidoc.com/oppidum/partial" at "lib/partial.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "lib/access.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "lib/services.xqm";
import module namespace excel = "http://oppidoc.com/oppidum/excel" at "lib/excel.xqm";
import module namespace console="http://exist-db.org/xquery/console";

declare variable $site:dico-uri := '/db/www/cctracker/config/dictionary.xml';

(: ======================================================================
   Trick to use request:get-uri behind a reverse proxy that injects
   /exist/projects/cctracker into the URL in production
   ======================================================================
:)
declare function local:my-get-uri ( $cmd as element() ) {
  concat($cmd/@base-url, $cmd/@trail, if ($cmd/@verb eq 'custom') then concat('/', $cmd/@action) else ())
};

(: ======================================================================
   Typeswitch function
   -------------------
   Plug all the <site:{module}> functions here and define them below
   ======================================================================
:)
declare function site:branch( $cmd as element(), $source as element(), $view as element()* ) as node()*
{
 typeswitch($source)
 case element(site:skin) return site:skin($cmd, $view)
 case element(site:navigation) return site:navigation($cmd, $view)
 case element(site:error) return site:error($cmd, $view)
 case element(site:message) return site:message($cmd)
 case element(site:login) return site:login($cmd)
 (:case element(site:lang) return site:lang($cmd, $view) :)
 case element(site:field) return site:field($cmd, $source, $view)
 case element(site:conditional) return site:conditional($cmd, $source, $view)
 case element(site:fop) return site:fop($cmd, $source, $view)
 case element(site:excel) return site:excel($cmd, $source, $view)
 case element(site:footer) return site:footer($cmd, $source, $view)
 default return $view/*[local-name(.) = local-name($source)]/*
 (: default treatment to implicitly manage other modules :)
};

declare function site:footer( $cmd as element(), $source as element(), $view as element() ) as element()*
{
  if ($cmd/@action eq 'login') then
    ()
  else
    <a id="xcm-login" href="{$cmd/@base-url}privacy-statement" target="_blank">Privacy statement</a>
};
(: ======================================================================
   Inserts CSS links and JS scripts to the page
   selection is defined by the current mesh, the optional skin attribute
   of the site:view element, and the site's 'skin.xml' resource
   ======================================================================
:)
declare function site:skin( $cmd as element(), $view as element() ) as node()*
{
  (
  skin:gen-skin('cctracker', oppidum:get-epilogue($cmd), $view/@skin),
  if (empty($view/site:links)) then () else skin:rewrite-css-link('cctracker', $view/site:links)
  )
};

(: ======================================================================
   Generates error essages in <site:error>
   ======================================================================
:)
declare function site:error( $cmd as element(), $view as element() ) as node()*
{
  let $resolved := oppidum:render-errors($cmd/@confbase, $cmd/@lang)
   return (
    (:    attribute class { 'active' },  :)
    for $m in $resolved/*[local-name() = "message"] return <p>{$m/text()}</p>
    )
};

(: ======================================================================
   Generates information messages in <site:message>
   Be careful to call session:invalidate() to clear the flash after logout redirection !
   ======================================================================
:)
declare function site:message( $cmd as element() ) as node()*
{
  let $messages := oppidum:render-messages($cmd/@confbase, $cmd/@lang)
  return
    for $m in $messages
    return (
      (: trick because messages are stored inside session :)
      if ($m/@type = "ACTION-LOGOUT-SUCCESS") then session:invalidate() else (),
      <p>
        {(
        for $a in $m/@*[local-name(.) ne 'type']
        return attribute { concat('data-', local-name($a)) } { string($a) },
        $m/(text()|*)
        )}
      </p>
      )
};

declare function local:gen-nav-class ( $name as xs:string, $target as xs:string*, $extra as xs:string?  ) as attribute()? {
  if ($name = $target) then
    attribute class { if ($extra) then concat($extra, ' active') else 'active' }
  else if ($extra) then
    attribute class { $extra }
  else
    ()
};

(: ======================================================================
   Generates <site:navigation> menu
   DEPRECATED :
   <li>{local:gen-nav-class($name, 'cases', ())}<a href="{$base}cases/create" loc="app.nav.case">Création cas</a></li>
   ======================================================================
:)
declare function site:navigation( $cmd as element(), $view as element() ) as element()*
{
  let $base := string($cmd/@base-url)
  let $rsc := string(oppidum:get-resource($cmd)/@name)
  let $name := if (starts-with($cmd/@trail, 'cases')) then
                 (: filters out everything not cases/create as 'stage' :)
                 if ($cmd/@action = 'create') then $rsc else 'stage'
               else
                 $rsc
   let $user := oppidum:get-current-user()
   let $groups := oppidum:get-current-user-groups()
  return
    <ul class="nav">
      <li>{local:gen-nav-class($name, 'stage', ())}<a href="{$base}stage" loc="app.nav.stage">Cas et activités</a></li>
      { if ($user eq 'guest') then () else partial:gen-todos-menu($base, $user, $groups) }
      <li>
        {local:gen-nav-class($name, ('regions', 'coaches', 'enterprises', 'persons'), 'dropdown')}
        <a class="dropdown-toggle" data-toggle="dropdown" href="#" loc="app.nav.communities">Communities</a>
        <ul class="dropdown-menu">
          <li><a href="{$base}regions" loc="app.nav.region">EEN</a></li>
          {
          if (access:check-omnipotent-user-for('search', 'Coach')) then
            <li><a href="{$base}coaches" loc="app.nav.coach">Coach</a></li>
          else
            (),
          if ($groups = 'coach') then
            <li><a href="{services:get-hook-address('ccmatch.links', 'ccmatch.coaches')}" loc="app.nav.coachmatch">CoachMatch</a></li>
          else
            ()
          }
          <li><a href="{$base}persons" loc="app.nav.persons">Persons</a></li>
          <li><a href="{$base}enterprises" loc="app.nav.enterprises">Entreprises</a></li>
        </ul>
      </li>
      <li>
        {local:gen-nav-class($name, ('CaseTrackerManual'), 'dropdown')}
        <a class="dropdown-toggle" data-toggle="dropdown" href="#" loc="app.nav.knowledge">Knowledge</a>
        <ul class="dropdown-menu">
          <li><a href="{$base}docs/cc20-organisation-handbook" target="_blank">SME Instrument Organisation Handbook 2.0</a></li>
          <li><a href="{$base}docs/cc20-method-handbook" target="_blank">SME Instrument Method Handbook 2.0</a></li>
          <li><a href="{$base}docs/cc20-kam-handbook" target="_blank">SME Instrument KAM Handbook 2.0</a></li>
          <li><a href="{$base}docs/cc20-coach-handbook" target="_blank">SME Instrument Coach Handbook 2.0</a></li>
          <li><a href="{$base}docs/cc20-case-tracker-handbook" target="_blank">SME Instrument Case Tracker Manual 3.0</a></li>
          <li><a href="https://ec.europa.eu/easme/sites/easme-site/files/documents/admin_steps_for_contract_and_payment_0.pdf" target="_blank">SME Instrument Coaching: Admin steps for contracting and payment</a></li>
          <li class="divider"></li>
          <li><a href="{$base}tools/cc20-bi-roadmap-tool.xlsx" target="_blank">BI Roadmap Tool (<i>excel</i>)</a></li>
          <li><a href="{$base}tools/cc20-bi-roadmap-handbook" target="_blank">BI Roadmap Methodology</a></li>
          <li><a href="{$base}tools/cc20-business-architecture-slides.pptx" target="_blank">Business Architecture Support (<i>power point</i>)</a></li>
          <li><a href="{$base}tools/cc20-macro-design-slides.pptx" target="_blank">Macro Design Support (<i>power point</i>)</a></li>
          <li><a href="{$base}tools/cc20-strategy-organisation-handbook" target="_blank">Strategy &amp; Organisation Methodology</a></li>
          <li><a href="{$base}tools/cc20-bi-segmentation-tool.xlsx" target="_blank">BI Segmentation Tool (<i>excel</i>)</a></li>
          <li><a href="{$base}tools/cc20-bi-customer-needs-analysis-tool.xlsx" target="_blank">BI Customer Needs Analysis Tool (<i>excel</i>)</a></li>
          <li><a href="{$base}tools/cc20-segmentation-customer-needs-slides.pptx" target="_blank">Segmentation &amp; Customer Needs Support (<i>power point</i>)</a></li>
          <li><a href="{$base}tools/cc20-segmentation-handbook" target="_blank">Segmentation Methodology</a></li>
          <li class="divider"></li>          
          <li><a href="{$base}forum/cooperation-aproach-edinburgh.pptx" target="_blank">Cooperation Approach Edinburgh (<i>power point</i>)</a></li>
          <li><a href="{$base}forum/absorptive-capacity-tool-DEMO.xlsx" target="_blank">Absorptive Capacity Assessment (<i>excel</i>)</a></li>
          
        </ul>
      </li>
      <li>{local:gen-nav-class($name, 'about', ())}<a href="{$base}about" loc="app.nav.guidelines">About</a></li>
      {
      if (($user = 'admin') or ($groups = ('admin-system'))) then (
        <li>
          {local:gen-nav-class($name, ('export', 'calls'), 'dropdown')}
          <a class="dropdown-toggle" data-toggle="dropdown" href="#">Tools</a>
          <ul class="dropdown-menu">
            <li class="dropdown-submenu">
              <a tabindex="-1" href="#">Export</a>
              { partial:gen-call-menu($base, 'export', 'en') }
            </li>
            <li class="dropdown-submenu">
              <a tabindex="-1" href="#">Assign</a>
              { partial:gen-call-menu($base, 'assign', 'en') }
            </li>
            <li><a href="{$base}reports">Reports</a></li>
          </ul>
        </li>,
        <li id="c-flush-right">{local:gen-nav-class($name, 'management', ())}<a href="{$base}management" loc="app.nav.admin">Admin</a></li>
        )
      else
        ()
      }
      {
      if (($user = 'admin') or ($groups = ('admin-system', 'business-intelligence', 'region-manager', 'ncp', 'kam'))) then
        <li>
          {local:gen-nav-class($name, ('cases', 'activities'), 'dropdown')}
          <a class="dropdown-toggle" data-toggle="dropdown" href="#" loc="app.nav.stats">Stats</a>
          <ul class="dropdown-menu">
            <li><a href="{$base}stats/cases" loc="app.nav.cases">Cases</a></li>
            <li><a href="{$base}stats/activities" loc="app.nav.activities">Activities</a></li>
            <li><a href="{$base}stats/kpi" loc="app.nav.kpi">KPI</a></li>
          </ul>
        </li>
      else
        ()
      }
    </ul>
};

(: ======================================================================
   Handles <site:login> LOGIN banner
   ======================================================================
:)
declare function site:login( $cmd as element() ) as element()*
{
 let
   $uri := local:my-get-uri($cmd),
   $user := oppidum:get-current-user()
 return
   if ($user = 'guest')  then
     if (not(ends-with($uri, '/login'))) then
       <a class="login" href="{$cmd/@base-url}login?url={$uri}">LOGIN</a>
     else
       <span>...</span>
   else
    let $user := (:if (string-length($user) > 7) then
                   if (substring($user,8,1) eq '-') then
                     substring($user, 1, 7)
                   else
                     concat(substring($user, 1, 7),'...')
                 else :)
                   $user
    return
      (
      <a href="{$cmd/@base-url}me" style="color:#333;text-decoration:none">{$user}</a>,
      <a class="login" href="{$cmd/@base-url}logout?url={$cmd/@base-url}">LOGOUT</a>
      )
};

(: ======================================================================
   Generates language menu
    - Simple logic so that default langauge (FR) is implicit (does not appear in URL)
   ======================================================================
:)
declare function site:lang( $cmd as element(), $view as element() ) as element()*
{
  let $lang := string($cmd/@lang)
  let $qs := request:get-query-string()
  let $uri := local:my-get-uri($cmd)
  return
    <span id="c-curLg">EN</span>
};

(: ======================================================================
   Applies a simple logic to filter conditional source blocks.
   Keeps (/ Removes) the source when all these conditions hold true (logical AND):
   - @avoid does not match current goal (/ matches goal)
   - @meet matches current goal (/ does not match goal)
   - @flag is present in the request parameters  (/ is not present in parameters)
   - @noflag not present in request parameters (/ is present in parameters)
   ======================================================================
:)
declare function site:conditional( $cmd as element(), $source as element(), $view as element()* ) as node()* {
  let $goal := request:get-parameter('goal', 'read')
  let $flags := request:get-parameter-names()
  return
    (: Filters out failing @meet AND @avoid and @noflag AND @flag :)
    if (not( 
               (not($source/@meet) or ($source/@meet = $goal))
           and (not($source/@avoid) or not($source/@avoid = $goal))
           and (not($source/@flag) or ($source/@flag = $flags))
           and (not($source/@noflag) or not($source/@noflag = $flags))
        )) 
    then
      ()
    else
      for $child in $source/node()
      return
        if ($child instance of element()) then
          (: FIXME: hard-coded 'site:' prefix we should better use namespace-uri
                    - currently limited to site:field :)
          if (starts-with(xs:string(node-name($child)), 'site:field')) then
            site:field($cmd, $child, $view)
          else
            local:render($cmd, $child, $view)
        else
          $child
};

(: ======================================================================
   Appends value $val to variable $var in XTiger param string
   (e.g. local:insert-param("a=b;c=d"; "a"; "e") returns "a=b e;c=d"
   ====================================================================== 
:)
declare function local:append-param( $var as xs:string, $val as xs:string?, $str as xs:string? ) as xs:string? {
  if ($val) then
    let $bound := concat($var, '=')
    return
      if (contains($str, $bound)) then
        replace ($str, concat($bound, '([^;]*)'), concat($bound, '$1 ', $val))
      else
        concat($str, if($str) then ';' else (), $bound, $val)
  else
    $str
};

(: ======================================================================
   Forms fields inclusion
   Fields marked as filter="copy" are removed or replaced with a constant
   field when readonly flag is set on the template URL.
   ======================================================================
:)
declare function site:field( $cmd as element(), $source as element(), $view as element()* ) as node()* {
  let $goal := request:get-parameter('goal', 'read')
  return
    if (($source/@avoid = $goal) or ($source/@meet and not($source/@meet = $goal))) then
      ()
    else if ($source[@filter = 'copy']) then
      if ($goal = 'read') then
        if ($source[@signature = 'multitext']) then (: sg <MultiText> :)
          <xt:use types="html" param="class=span a-control" label="{$source/xt:use/@label}"/>
        else if ($source[@signature = 'plain']) then (: sg <Plain> :)
          <xt:use types="constant" label="{$source/xt:use/@label}"/>
        else if ($source/xt:use[@types='input']) then (: sg <Input> :)
          let $media := if (contains($source/xt:use/@param, 'constant_media=')) then concat(';constant_media=', substring-after($source/xt:use/@param, 'constant_media=')) else ''
          return
            <xt:use types="constant" param="class=uneditable-input span a-control{$media}">
              { $source/xt:use/@label }
            </xt:use>
        else if ($source/xt:use[@types='text']) then (: sg <Text> :)
          <xt:use types="constant" param="class=sg-multiline uneditable-input span a-control">
            { $source/xt:use/@label }
          </xt:use>
        else if ($source[@signature = 'richtext']) then (: sg <RichText> :)
          <xt:use types="html" param="class=span a-control" label="{$source/div/xt:repeat/@label}"/>
        else if ($source[@signature = 'append']) then (: sg <Constant> with @Append :)
          <div class="input-append fill">
            <xt:use param="class=uneditable-input fill a-control text-right;" label="{$source/@Tag}" types="constant"></xt:use>
            { $source/div/span }
          </div>
        else
          $source/*
      else
        $source/*
    else
      let $f := $view/site:field[@Key = $source/@Key]
      return
        if ($f) then
          if ($f[@filter = 'no']) then
            $f/*
          else
            (: we could use @Size but span12 is compatible anywhere in row-fluid :)
            (: FIXME: for types="constant" you must set the correct span :)
            <xt:use localized="1">
              {
              (: 1. duplicates non-modifiable XTiger plugin attributes :)
              $f/xt:use/(@types|@values|@i18n|@default),
              (: 2. rewrites (or generates) XTiger @param :)
              let $lang := string($cmd/@lang)
              let $ext :=  (
                if ($source/@Required) then 'required=true' else (),
                if ($source/@Placeholder-loc) then concat('placeholder=',site:get-local-string($lang, $source/@Placeholder-loc)) else ()
                )
              return
                if (exists($ext) or exists($source/@Filter)) then
                  attribute { 'param' } {
                    let $filtered := local:append-param('filter', $source/@Filter, $f/xt:use/@param)
                    let $more := if ($ext) then string-join($ext, ';') else ()
                    return
                      if ($filtered) then
                        concat($filtered, ';', $more )
                      else
                        $more
                  }
                else
                  $f/xt:use/@param,
              (: 3. duplicates or generates XTiger @label :)
              if ($f/xt:use/@label) then $f/xt:use/@label else attribute { 'label' } { $source/@Tag/string() },
              (: 4. duplicates text content :)
              $f/xt:use/text()
              }
            </xt:use>
        else
          (: plain constant field (no id, no appended symbol) :)
          <xt:use types="constant" label="{$source/@Tag}" param="class=uneditable-input span a-control"/>
};

(: ======================================================================
   Generates pdf document using fop
   ======================================================================
:)
declare function site:fop( $cmd as element(), $source as element(), $view as element()* ) as node()* {
  let $pdf := xslfo:render($view, "application/pdf", ())
  return
    response:stream-binary($pdf, "application/pdf", "coaching-plan.pdf")
};

(: ======================================================================
   Generates pdf document using fop
   ======================================================================
:)
declare function site:excel( $cmd as element(), $source as element(), $view as element()* ) as node()* {
  let $bin := 
    if ($view instance of element(ms:sheetData)) then
      excel:create-xlsx-from-sheet($view, '20', true(), true())
    else if (local-name($view/*[1]) eq 'row') then (: local-name() because of default namespace :)
      excel:create-xlsx-from-row-table($view, '20', true(), true())
    else
      ()
  return
    if (empty($bin)) then 
      $view
    else
      let $fn := if ($view/@fn) then string($view/@fn) else 'out'
      return
        response:stream-binary($bin, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", concat($fn, ".xlsx"))
};

(: ======================================================================
   Recursive rendering function
   ----------------------------
   Copy this function as is inside your epilogue to render a mesh
   ======================================================================
:)
declare function local:render( $cmd as element(), $source as element(), $view as element()* ) as element()
{
  element { node-name($source) }
  {
    $source/@*,
    for $child in $source/node()
    return
      if ($child instance of text()) then
        $child
      else
        (: FIXME: hard-coded 'site:' prefix we should better use namespace-uri :)
        if (starts-with(xs:string(node-name($child)), 'site:')) then
          (
            if (($child/@force) or
                ($view/*[local-name(.) = local-name($child)])) then
                 site:branch($cmd, $child, $view)
            else
              ()
          )
        else if ($child/*) then
          if ($child/@condition) then
          let $go :=
            if (string($child/@condition) = 'has-error') then
              oppidum:has-error()
            else if (string($child/@condition) = 'has-message') then
              oppidum:has-message()
            else if ($view/*[local-name(.) = substring-after($child/@condition, ':')]) then
                true()
            else
              false()
          return
            if ($go) then
              local:render($cmd, $child, $view)
            else
              ()
        else
           local:render($cmd, $child, $view)
        else
         $child
  }
};

(: ======================================================================
   Returns a localized string for a given $lang and $key
   ======================================================================
:)
declare function site:get-local-string( $lang as xs:string, $key as xs:string ) as xs:string {
  let $res := fn:doc($site:dico-uri)/site:Dictionary/site:Translations[@lang = $lang]/site:Translation[@key = $key]/text()
  return
    if ($res) then
      $res
    else
      concat('missing [', $key, ', lang="', $lang, '"]')
};

(: ======================================================================
   Typeswitch function
   -------------------
   Filters loc and {name}-loc attributes to localize content using a dictionary
   $dict is a dictionary element with a @lang attribute
   ======================================================================
:)
declare function site:localize( $dict as element()?, $source as element(), $sticky as xs:boolean ) as node()*
{
  if ($source/@localized) then (: optimization mainly for search results tables :)
    $source
  else
  element { node-name($source) }
  {
    if ($sticky) then $source/@loc else (),
    for $attr in $source/@*[local-name(.) ne 'loc']
    let $name := local-name($attr)
    return
      if (ends-with($name, '-loc')) then
        let $key := string($attr)
        let $t := $dict/site:Translation[@key = $key]/text()
        return attribute { substring-before($name, '-loc') } { if ($t) then $t else concat('missing [', $key,', lang="', string($dict/@lang), '"]') }
      else if ($source/@*[local-name(.) = concat($name, '-loc')]) then (: skip it :)
        ()
      else
        $attr,
    for $child in $source/node()
    return
      if ($child instance of text()) then
        if ($source/@loc) then
          let $t := $dict/site:Translation[@key = string($source/@loc)]/text()
          return
            if ($t) then
              $t
            else (
              <span style="color:red">
              {
              concat('missing [', string($source/@loc), ', lang="', string($dict/@lang), '"]')
              }
              </span>
            )
        else
          $child
      else if ($child instance of element()) then
        site:localize($dict, $child, $sticky)
      else
        $child (: FIXME: should we care about other stuff like coments ? :)
  }
};

(: ======================================================================
   Utility to switch on/off translation tool
   Trick so that translation agent persists when loading the formular after the regular page load
   SHOULD be removed in production
   ======================================================================
:)
declare function local:translation-agent( ) as xs:boolean {
  let $t-req := request:get-parameter('t', '') (: translation agent :)
  return
    if ($t-req = '') then
      if (session:exists() and session:get-attribute('t-agent')) then true() else false()
    else if ($t-req = 'off') then (
      if (session:exists()) then session:remove-attribute('t-agent') else (),
      false()
      )
    else (
      if (session:exists()) then session:set-attribute('t-agent', true()) else (),
      true()
      )
};

(: ======================================================================
   Epilogue entry point
   --------------------
   Copy this code as is inside your epilogue
   ======================================================================
:)
let $mesh := epilogue:finalize()
let $cmd := request:get-attribute('oppidum.command')
let $sticky := false() (:local:translation-agent():)
let $lang := $cmd/@lang
let $dico := fn:doc($site:dico-uri)/site:Dictionary/site:Translations[@lang = $lang]
let $isa_tpl := contains($cmd/@trail,"templates/") or ends-with($cmd/@trail,"/template")
let $maintenance := partial:filter-for-maintenance($cmd, $isa_tpl)
return
  if ($mesh) then
    let $type := if (matches($cmd/@trail, "^import|test/|^calls/|activities/") or $isa_tpl) then
                      "method=html media-type=application/xhtml+xml"
                   else
                     "method=html5 media-type=text/html"
    let $page := local:render($cmd, $mesh, oppidum:get-data())
    return (
       util:declare-option("exist:serialize", concat($type, " encoding=utf-8 indent=yes")),
      site:localize($dico, $page, $sticky)
      )
  else
    site:localize($dico, oppidum:get-data(), $sticky)
