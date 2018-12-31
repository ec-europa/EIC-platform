xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Copy and customize this file to finalize your application page generation

   January 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace request = "http://exist-db.org/xquery/request";
declare namespace session = "http://exist-db.org/xquery/session";
declare namespace response="http://exist-db.org/xquery/response";
declare namespace util="http://exist-db.org/xquery/util";

declare namespace ms = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "lib/globals.xqm";
import module namespace epilogue = "http://oppidoc.com/oppidum/epilogue" at "../oppidum/lib/epilogue.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../xcm/lib/access.xqm";
import module namespace view = "http://oppidoc.com/ns/xcm/view" at "../xcm/lib/view.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "app/custom.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "modules/enterprises/enterprise.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../xcm/lib/user.xqm";
import module namespace excel = "http://oppidoc.com/oppidum/excel" at "lib/excel.xqm";
(:import module namespace partial = "http://oppidoc.com/oppidum/partial" at "app/partial.xqm";:)

(: ======================================================================
   Trick to use request:get-uri behind a reverse proxy that injects
   /exist/projets//cockpit into the URL in production
   ======================================================================
:)
declare function local:my-get-uri ( $cmd as element() ) {
  concat($cmd/@base-url, $cmd/@trail, if ($cmd/@verb eq 'custom') then if ($cmd/@trail eq '') then $cmd/@action else concat('/', $cmd/@action) else ())
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
 case element(site:skin) return view:skin($cmd, $view)
 case element(site:navigation) return site:navigation($cmd, $view)
 case element(site:error) return view:error($cmd, $view)
 case element(site:message) return view:message($cmd)
 case element(site:login) return site:login($cmd, $view)
 case element(site:title) return site:title($cmd, $view)
 case element(site:field) return view:field($cmd, $source, $view)
 case element(site:conditional) return site:conditional($cmd, $source, $view)
 case element(site:excel) return site:excel($cmd, $source, $view)
 case element(site:resources) return site:resources($cmd, $source, $view)
 case element(site:footer) return site:footer($cmd, $source, $view)
 case element(site:layout) return site:layout($cmd, $source, $view)
 default return $view/*[local-name(.) = local-name($source)]/*
 (: default treatment to implicitly manage other modules :)
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
   FIXME: primitive version to be improved
   ======================================================================
:)

declare function site:navigation( $cmd as element(), $view as element() ) as element()*
{
  custom:gen-navigation-menu($cmd, $view/site:model/*[local-name() eq 'Navigation'])
};



(:Generates the footer with the link of the privacy statement :)
declare function site:footer( $cmd as element(), $source as element(), $view as element() ) as element()*
{
  if ($cmd/@action eq 'login') then
    ()
  else
    <a class="ecl-link ecl-link--inverted ecl-footer__link" href="{$cmd/@base-url}files/privacy-statement-calls-EASME" target="_blank">Privacy statement</a>
};

(: ======================================================================
   Generates the container for the whole content
   ======================================================================
:)
declare function site:layout( $cmd as element(), $source as element(), $view as element() ) as element()*
{
  <div class="{if (exists($view//site:layout)) then $view//site:layout else 'ecl-container'}">
    {
      for $child in $source/node()
      return
        if (starts-with(xs:string(node-name($child)), 'site:')) then
          (
            if (($child/@force) or
                ($view/*[local-name(.) = local-name($child)])) then
                 site:branch($cmd, $child, $view)
            else
              ()
          )
        else if ($child instance of element()) then
          local:render($cmd, $child, $view)
        else
          $child
    }
  </div>
};
(: ======================================================================
   Generate user name display in header with a link to user's current 
   company dashboard, a link to the multi-dashboard for aministrator,
   or no link at all, just a name to show
   FIXME: To be put into app/custom.xqm
   ====================================================================== 
:)
declare function local:gen-user-name( $cmd as element(), $name as xs:string ) as element() {
  let $groups := oppidum:get-current-user-groups()
  return 
    if ($groups = ('admissible', 'pending-investor')) then 
      <span class="ecl-navigation-list__link">self registered user</span>
    else
      let $self-click := 
        if (oppidum:get-current-user-groups() = ('project-officer', 'admin-system', 'developer', 'events-manager', 'dg')) then
          (: should lead to multi-dashboard :)
          oppidum:get-current-user() 
        else 
          (: should lead to current company dashboard :)
          if (matches($cmd/@trail, '^\d+$')) then
            () (: already there :)
          else
            let $company := tokenize($cmd/@trail,'/')[2]
            return
              if (matches($company, '^\d+$')) then
                $company
              else
                ()
      return
        if ($self-click and $cmd/@trail ne $self-click) then
          <a id="xcm-login" class="ecl-link ecl-navigation-list__link" href="{$cmd/@base-url}{$self-click}">{$name}</a>
        else
          let $self-click := 
            if ($groups = ('project-officer', 'admin-system', 'developer', 'events-manager', 'dg')) then
              (: should lead to multi-dashboard :)
              oppidum:get-current-user() 
            else
              (: should lead to current company dashboard :)
              if (matches($cmd/@trail, '^\d+$')) then
                () (: already there :)
              else
                let $company := tokenize($cmd/@trail,'/')[2]
                return
                  if (matches($company, '^\d+$')) then
                    $company
                  else if ($cmd/@action eq 'login') then (: inject company id :)
                    enterprise:default-redirect-to(())
                  else
                    ()
          return
            if ($self-click) then
              <a id="xcm-login" class="ecl-link ecl-navigation-list__link" href="{$cmd/@base-url}{$self-click}">{$name}</a>
            else
              <span class="ecl-navigation-list__link">{$name}</span>
};

declare function site:title ( $cmd as element(), $view as element() ) as element()
{
  <div class='ecl-navigation-list__title'>{ $view//site:title/text() }</div>
};

(: ======================================================================
   Handles <site:login> LOGIN banner
   ======================================================================
:)
declare function site:login( $cmd as element(), $view as element() ) as element()*
{
 let
   $uri := local:my-get-uri($cmd),
   $user := oppidum:get-current-user()
 return
   if ($user = 'guest')  then
     if ($cmd/@action eq 'welcome') then
       ()
     else if (starts-with($cmd/@trail, 'feedbacks')) then
       $view/site:login/*
     else if (ends-with($uri, '/logout')) then
       <a class="ecl-link ecl-navigation-list__link" href="{$cmd/@base-url}login">Login</a>
     else if (not(ends-with($uri, '/login'))) then
       <a class="ecl-link ecl-navigation-list__link" href="{$cmd/@base-url}login?url={$uri}">Login</a>
     else
       <a class="ecl-link ecl-navigation-list__link" href="{$cmd/@base-url}login?url={$uri}">Login</a>
   else
     let $id := user:get-current-person-id()
     let $name := custom:gen-person-name($id,'en')
     (:let $name := oppidum:get-current-user():)
     let $nb-enterprises := enterprise:count-my-enterprises()
     return
       if ($name = '') then
        (<li class="ecl-navigation-list__item">
           <a class="ecl-link ecl-navigation-list__link" href="{$cmd/@base-url}logout?url={$cmd/@base-url}">Log out</a>
         </li>)
        
       else (
         local:gen-user-name($cmd, $name),
        (: <li class="ecl-navigation-list__item" style=""> xxxx</li>,:)
          <li class="ecl-navigation-list__item">
            <a class="ecl-link ecl-navigation-list__link" href="{$cmd/@base-url}logout?url={$cmd/@base-url}">Log out</a>
          </li>,
         if ($nb-enterprises > 1) then
           (
           <br/>,
           <span class="ecl-navigation-list__link">You are registered in <a href="{$cmd/@base-url}switch">{$nb-enterprises}</a> teams</span>
           )
         else
           ()
         )
};

(: ======================================================================
   Implements <site:conditional> in mesh files (e.g. rendering a Supergrid
   generated mesh XTiger template).

   Applies a simple logic to filter conditional source blocks.

   Keeps (/ Removes) the source when all these conditions hold true (logical AND):
   - @avoid does not match current goal (/ matches goal)
   - @meet matches current goal (/ does not match goal)
   - @flag is present in the request parameters  (/ is not present in parameters)
   - @noflag not present in request parameters (/ is present in parameters)

   TODO: move to view module with XQuery 3 (local:render as parameter)
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
            view:field($cmd, $child, $view)
          else
            local:render($cmd, $child, $view)
        else
          $child
};

(: ======================================================================
   Recursive rendering function
   ----------------------------
   Copy this function as is inside your epilogue to render a mesh
   TODO: move to view module with XQuery 3 (site:branch as parameter)
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

(: =======================================================================
   Downloads zip files 
   FIXME: is there a way to directly pass binary files to compression:zip 
   w/o serializing to memory (very consuming) ?
   =======================================================================
:)
declare function site:resources( $cmd as element(), $source as element(), $view as element()* ) as node()* {
  let $all-entries := 
    for $entry in $view//*[local-name(.) eq 'entry']
    return
      <entry type="binary" method="store" name='{ $entry/@name }'>
        { util:binary-doc($entry/@path)}
      </entry>
  let $zip-file := compression:zip($all-entries, true())
  return 
   response:stream-binary($zip-file, "application/zip", "resources.zip")
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
   Epilogue entry point
   ======================================================================
:)
let $mesh := epilogue:finalize()
let $cmd := request:get-attribute('oppidum.command')
let $sticky := false() (: TODO: support for forthcoming local:translation-agent() :)
let $lang := $cmd/@lang
let $dico := fn:doc($globals:dico-uri)/site:Dictionary/site:Translations[@lang = $lang]
let $isa_tpl := contains($cmd/@trail,"templates/") or ends-with($cmd/@trail,"/template")
let $maintenance := view:filter-for-maintenance($cmd, $isa_tpl)
return
  if ($mesh) then
    (: FIXME: use site:view attribute to select media-type ? :)
    let $option := if (matches($cmd/@trail, "ranking$") or matches($cmd/@trail, "^(teams|events)/import") or matches($cmd/@trail, "^test/") or $isa_tpl) then
                     "method=html media-type=application/xhtml+xml"
                   else
                     "method=html5 media-type=text/html"
    let $page := local:render($cmd, $mesh, oppidum:get-data())
    return
      (
      util:declare-option("exist:serialize", concat($option, " encoding=utf-8 indent=yes")),
      view:localize($dico, $page, $sticky)
      )
  else
    view:localize($dico, oppidum:get-data(), $sticky)
