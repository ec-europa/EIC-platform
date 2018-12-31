xquery version "3.0";
(:~ 
 : Cockpit - EIC SME Dashboard Application
 :
 : This module provides the helper functions that depend on the application
 : specific data model, such as :
 : <ul>
 : <li> label generation for different data types (display)</li>
 : <li> drop down list generation to include in formulars (form)</li>
 : <li> access control rules implementation (access)</li>
 : <li> miscellanous utilities (misc)</li>
 : </ul>
 : 
 : You most probably need to update that module to reflect your data model.
 : 
 : NOTE: actually eXist-DB does not support importing several modules
 : under the same prefix. Once this is supported this module could be 
 : splitted into corresponding modules (display, form, access, misc)
 : to be merged through import with their generic module counterpart.
 :
 : January 2017 - European Union Public Licence EUPL
 :
 : @author Stéphane Sire
 :)
module namespace custom = "http://oppidoc.com/ns/application/custom";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";
import module namespace cache = "http://oppidoc.com/ns/xcm/cache" at "../../xcm/lib/cache.xqm";
import module namespace database = "http://oppidoc.com/ns/xcm/database" at "../../xcm/lib/database.xqm";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../xcm/modules/users/account.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../lib/display.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../xcm/lib/form.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../xcm/lib/user.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../modules/enterprises/enterprise.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";

(: to be moved to menu.xml ? :)
declare variable $custom:menu := 
  <Navigation>
    <Menu Id="multi" Group="admin-system project-officer developer">
      <Option Key="communication"/>
      <Option Key="teams" Path="teams">
        <Label Rank="2">Teams</Label>
        <Todos>
          <Label Prior="1">
            <Content Role="admin-system" Agg="count" Collection="enterprises"><XPath>//Enterprise/Team/Members/Member[not(PersonRef)][not(Rejected)]</XPath> pending user(s) for accreditation!</Content>
            <Content Role="project-officer" Agg="count" Collection="enterprises"><XPath>//Enterprise[Projects/Project/ProjectOfficerKey = $uid]/Team/Members/Member[not(PersonRef)][not(Rejected)]</XPath> pending user(s) for accreditation!</Content>
          </Label>
        </Todos>
      </Option>
      <Option Key="events" Path="events">
        <Label Rank="3">Events</Label>
      </Option>
      <Option Key="coaching"/>
      <Option Key="companies" Path="enterprises">
        <Label Rank="1">Companies</Label>
      </Option>
      <Option Key="grant"/>
      <Option Key="admin" Path="management">
        <Label Rank="2">Admin</Label>
      </Option>
      <Option Key="investors">
        <Actions>
          <Open Resource="ScaleupEU" Service="invest">Go to matching service</Open>
          <Token/>
        </Actions>
      </Option>
      <Option Key="alerts"/>
    </Menu>
    <Menu Id="dg" Group="dg">
      <Option Key="communication"/>
      <Option Key="teams" Path="teams">
        <Label Rank="2">Teams</Label>
      </Option>
      <Option Key="events" Path="events">
        <Label Rank="3">Events</Label>
      </Option>
      <Option Key="coaching"/>
      <Option Key="companies" Path="enterprises">
        <Label Rank="1">Companies</Label>
      </Option>
      <Option Key="grant"/>
      <Option Key="admin"/>
      <Option Key="investors"/>
      <Option Key="alerts"/>
    </Menu>
    <Menu Id="unaffiliated" Group="events-manager facilitator monitor">
      <Option Key="communication"/>
      <Option Key="teams"/>
      <Option Key="events" Path="events" Group="events-manager">
        <Label Rank="3">Events</Label>
      </Option>
      <Option Key="coaching"/>
      <Option Key="companies"/>
      <Option Key="grant"/>
      <Option Key="admin"/>
      <Option Key="investors" Group="facilitator monitor">
        <Actions>
          <Open Resource="ScaleupEU" Service="invest">Go to matching service</Open>
          <Token/>
        </Actions>
      </Option>
      <Option Key="alerts"/>
    </Menu>
    <Menu Id="evmgr-single">
      <!-- top menu for an event manager viewing a company dashboard -->
      <Option Key="communication"/>
      <Option Key="teams"/>
      <Option Key="events" Mapping="events">
        <Label Rank="3" Pipe="no" Legend="company">Other events</Label>
      </Option>
      <Option Key="coaching"/>
      <Option Key="companies"/>
      <Option Key="grant"/>
      <Option Key="admin"/>
      <Option Key="investors"/>
      <Option Key="alerts"/>
    </Menu>
    <Menu Id="single">
      <Option Key="communication"/>
      <Option Key="team" Mapping="teams">
        <Label Rank="2">Team</Label>
      </Option>
      <Option Key="events" Mapping="events">
        <Label Rank="3">Events</Label>
        <Todos>
          <Label Prior="1"><Content Agg="count" Context="$enterprise"><XPath>//Events/Event[StatusHistory/CurrentStatusRef/text() eq '1']</XPath> application(s) to submit!</Content></Label>
          <Label Prior="2"><Content Agg="count" Collection="events"><XPath>//Event/Id[Application/From le string(current-date()) and string(current-date() le Application/To) ][not(. = $enterprise/Events/Event/Id)]</XPath> event(s) are still open for registration</Content></Label>
        </Todos>
      </Option>
      <Option Key="coaching"/>
      <Option Key="company" Mapping="enterprises">
        <Label Rank="1">Company</Label>
      </Option>
      <Option Key="grant"/>
      <Option Key="who-is-who"/>
      <Option Key="investors">
        <Actions>
          <Open Resource="ScaleupEU" Service="invest">Go to matching service</Open>
          <Token/>
        </Actions>
      </Option>
      <Option Key="community">
        <Actions>
          <Open Resource="Community" Service="community">Go to EIC Community</Open>
        </Actions>
      </Option>
    </Menu>
    <Menu Id="een">
      <Option Key="communication"/>
      <Option Key="team" Mapping="teams">
        <Label Rank="2">Team</Label>
      </Option>
      <Option Key="events" Mapping="events">
        <Label Rank="3">Events</Label>
      </Option>
      <Option Key="company" Mapping="enterprises">
        <Label Rank="1">Company</Label>
      </Option>
      <Option Key="community">
        <Actions>
          <Open Resource="Community" Service="community">Go to EIC Community</Open>
        </Actions>
      </Option>
    </Menu>
  </Navigation>;

(: ======================================================================
   Return the name of the Menu to use to generate the user's Dashboard
   or navigation menu.
   ====================================================================== 
:)
declare function custom:get-dashboard-for-group( $groups as xs:string* ) as xs:string { 
  ($custom:menu/Menu[tokenize(@Group, ' ') = $groups]/@Id, 'multi')[1]
};

declare function local:gen-home-link ( $base as xs:string, $mode as xs:string, $nav as element()? ) {
  if ($mode = ('multi','unaffiliated', 'dg')) then
    let $resource := oppidum:get-current-user()
    return (
      <xhtml:li class="ecl-navigation-menu__item">
          <xhtml:a href="{$base}{$resource}" class="ecl-navigation-menu__link">Home</xhtml:a>
      </xhtml:li>
      )
  else if ($mode eq 'single') then (
    <xhtml:li class="ecl-navigation-menu__item">
        <xhtml:a href="{$base}{$nav/Resource}" class="ecl-navigation-menu__link">Home</xhtml:a>
    </xhtml:li>
    )
  else (: assumes 'evmgr-single' :) 
    <xhtml:img id="logo" src="{$base}static/cockpit/images/home.png"/>
};

(: ======================================================================
   Generates contextual application primary navigation menu
   (to be called by the epilogue)
   TODO: to be moved to app/view.xqm ?
   ====================================================================== 
:)
declare function custom:gen-navigation-menu( $cmd as element(), $nav as element()? ) as element()* {
  let $base := string($cmd/@base-url)
  return
    if ($nav/Mode eq 'dashboard') then
      <xhtml:div class="ecl-page-header__title">{
      if (exists($nav/REST)) then 
            <xhtml:sup style="font-size: 14px;margin: 15px 5px; float: right;"><xhtml:a href="{$nav/REST}" class="login">xml</xhtml:a></xhtml:sup>
          else
            ()
            }
            <xhtml:h1 class="ecl-heading--h1" style="color:#2d2d2d; font-size: 1.1rem;"> {$nav/Name/text()}{ if ($nav/Name/@Satellite) then <xhtml:sup style="margin-left:10px">{ string($nav/Name/@Satellite) }</xhtml:sup> else () }</xhtml:h1>
      </xhtml:div>
    else if ($nav/Mode = ('single', 'evmgr-single')) then 
      (
      <xhtml:button class="ecl-navigation-menu__toggle ecl-navigation-menu__hamburger ecl-navigation-menu__hamburger--squeeze" aria-controls="nav-menu-expandable-root" aria-expanded="false">
          <xhtml:span class="ecl-navigation-menu__hamburger-box">
            <xhtml:span class="ecl-navigation-menu__hamburger-inner"/>
          </xhtml:span>
          <xhtml:span class="ecl-navigation-menu__hamburger-label">Menu</xhtml:span>
      </xhtml:button>,
      <xhtml:ul class="ecl-navigation-menu__root" id="nav-menu-expandable-root" aria-hidden="true">
      {
        local:gen-home-link ($base, $nav/Mode, $nav),
        for $option in $custom:menu/Menu[@Id eq $nav/Mode]/Option[@Mapping]
        let $pipe := if ($option/Label/@Pipe eq 'no') then () else ()
        order by $option/Label/@Rank
        return (
          if ($option/@Key eq $nav/Key) then
            ($pipe, <xhtml:li class="ecl-navigation-menu__item ecl-navigation-menu__item--active"><xhtml:span class="ecl-navigation-menu__link">{ $option/Label/text() }</xhtml:span></xhtml:li>)
          else (
            $pipe,
            <xhtml:a href="{$base}{$option/@Mapping}/{$nav/Resource}" class="ecl-navigation-menu__link">{$option/Label/text()}</xhtml:a>
            ),
          if ($option/Label/@Legend) then 
            (' (', <xhtml:i>{ string($option/Label/@Legend) }</xhtml:i>, ') ') 
          else 
            ()
          )
        }
        <!-- <xhtml:h1 style="float:right">{ $nav/Name/text() }</xhtml:h1> -->
      </xhtml:ul>
      )
    else if ($nav/Mode = ('multi','unaffiliated', 'dg')) then
      (
      <xhtml:button class="ecl-navigation-menu__toggle ecl-navigation-menu__hamburger ecl-navigation-menu__hamburger--squeeze" aria-controls="nav-menu-expandable-root" aria-expanded="false">
          <xhtml:span class="ecl-navigation-menu__hamburger-box">
            <xhtml:span class="ecl-navigation-menu__hamburger-inner"/>
          </xhtml:span>
          <xhtml:span class="ecl-navigation-menu__hamburger-label">Menu</xhtml:span>
      </xhtml:button>,
      <xhtml:ul class="ecl-navigation-menu__root" id="nav-menu-expandable-root" aria-hidden="true">
        {
        local:gen-home-link ($base, $nav/Mode, $nav),
        for $option in $custom:menu/Menu[@Id eq $nav/Mode]/Option[@Path]
        order by $option/Label/@Rank
        return
          if ($option/@Key eq $nav/Key) then
            <xhtml:li class="ecl-navigation-menu__item ecl-navigation-menu__item--active"><xhtml:span class="ecl-navigation-menu__link">{ $option/Label/text() }</xhtml:span></xhtml:li> 
          else
            <xhtml:li class="ecl-navigation-menu__item"><xhtml:a href="{$base}{$option/@Path}" class="ecl-navigation-menu__link">{$option/Label/text()}</xhtml:a></xhtml:li> 
        }
        <!--<xhtml:h1 style="float:right">{ $nav/Name/text() }</xhtml:h1> -->
      </xhtml:ul>
      )
    else
      ()
};

(: ======================================================================
   Generates a memory cache to associate project officer names with 
   their ECAS remote key
   NOTE: Hard-coded project officer role
   ====================================================================== 
:)
declare function custom:gen-project-officers-map() as map() {
  map:new(
    let $persons := globals:collection('persons-uri')/Person
    return
      for $po-person in $persons[.//FunctionRef = '2']
      let $key := $po-person//Remote[@Name eq 'ECAS']/text()
      where $key
      return
        map:entry(
          $key,
          custom:gen-person-name($po-person/Id, 'en')
        )
    )
};

(: ======================================================================
   Returns the name of the project officer if s/he is recorded as a user
   with access to the application
   ====================================================================== 
:)
declare function custom:gen-project-officer-name( $key as xs:string? ) as xs:string? {
  if ($key) then
    let $p-o := globals:collection('persons-uri')/Person[UserProfile/Remote[@Name eq 'ECAS'] eq $key]
    return
        custom:gen-person-name($p-o/Id, 'en')
  else
    ()
};

(: ======================================================================
   TODO: move to misc ? improve by looking for spaces around $max
   ====================================================================== 
:)
declare function local:shorten-name( $str as xs:string?, $max as xs:integer ) as xs:string? {    
  if (string-length($str) > $max) then
    if (substring($str, $max, 1) eq ' ') then
      substring($str,1 , $max)
    else
      concat(substring($str, 1, $max), '...')
  else
    $str
};

(: ======================================================================
   Generates a person name (First name, Surname) from a reference to a person
   Uses the first company Member record when the person is linked with 
   multiple companies
   ======================================================================
:)
declare function custom:gen-person-name( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := (fn:collection($globals:enterprises-uri)//Member[PersonRef = $ref])[1]
    return
      if (exists($p)) then
        concat($p/Information/Name/FirstName, ' ', $p/Information/Name/LastName)
      else 
        let $master := fn:collection($globals:persons-uri)//Person[Id eq $ref]/Information
        return (: use master copy when available :)
          if ($master) then
            concat($master/Name/FirstName, ' ', $master/Name/LastName)
          else
            display:noref($ref, $lang)
  else
    ""
};

declare function custom:gen-name-person( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := (fn:collection($globals:enterprises-uri)//Member[PersonRef = $ref])[1]
    return
      if (exists($p)) then
        concat($p/Information/Name/LastName, ' ', $p/Information/Name/FirstName)
      else
        let $master := fn:collection($globals:persons-uri)//Person[Id eq $ref]/Information
        return (: use master copy when available :)
          if ($master) then
            concat($master/Name/LastName, ' ', $master/Name/FirstName)
          else
            display:noref($ref, $lang)
  else
    ""
};

(: ======================================================================
   Generates an event name from an event meta-data document
   ======================================================================
:)
declare function custom:gen-event-name( $event-def as element()? ) as xs:string {
  let $info := $event-def/Information
  return
    if ($info/Name/@Extra) then
      concat($info/Name, ' (', $info/*[local-name() eq $info/Name/@Extra], ')')
    else
      string($info/Name)
};

(: ======================================================================
   Generates an enterprise name from a reference to an enterprise
   ======================================================================
:)
declare function custom:gen-enterprise-name( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $e := globals:collection('enterprises-uri')//Enterprise[Id = $ref]
    return
      if ($e) then
        $e/Information/Name/text()
      else
        display:noref($ref, $lang)
  else
    ""
};

(: ======================================================================
   Generates a short version of enterprise name to disaply in headers
   TODO: implement a $max-length parameter
   ======================================================================
:)
declare function custom:gen-enterprise-title( $e as element()? ) {
  if ($e) then
    local:shorten-name(
      if ($e/Information/ShortName) then
        $e/Information/ShortName
      else
        $e/Information/Name,
      40
    )
  else
    'unknown company'
};

(: ======================================================================
   Generates event name from event meta-data
   ====================================================================== 
:)
declare function custom:gen-event-title( $event as element() ) as xs:string? {
  let $name := $event/Information/Name
  return
    if (not($name/@Extra)) then
      $name
    else
      concat($name, ' (', $event/Information/*[local-name(.) = $name/@Extra], ')')
};

(: ======================================================================
   Generates an element with a given tag holding the display name of the enterprise
   passed as a parameter and its reference as content
   ======================================================================
:)
declare function custom:unreference-enterprise( $ref as element()?, $tag as xs:string, $lang as xs:string ) as element() {
  let $sref := $ref/text()
  return
    element { $tag }
      {(
      attribute { '_Display' } { custom:gen-enterprise-name($sref, $lang) },
      $sref
      )}
};

(:=======================================================================

  =======================================================================
:)
declare function custom:gen-projects-acronym( $ref as xs:string?, $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $n in enterprise:list-valid-projects($ref)
      order by $n ascending
      return
         <Name id="{$n/ProjectId/text()}">{ replace(concat( $n/Acronym, ' (', $n/ProjectId, ')'),' ','\\ ')}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n, ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};


declare function custom:gen-all-projects-acronym( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('acronyms', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" i18n="{$inCache/I18n}" param="{form:setup-select2($params)}"/>
    else
      let $pairs :=
          for $n in globals:collection('enterprises-uri')//Project
          let $id := $n/ProjectId
          group by $id
          return
            if ($id ne '') then (: sanity check :)
              <Name id="{$id}">{ replace($n[1]/Acronym,' ','\\ ') }</Name>
            else
              ()
      return
        let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
        let $names := string-join(for $n in $pairs return $n, ' ') (: idem :)
        return (
          cache:update('acronyms',$lang, $ids, $names),
           <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
          )
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a team member
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   To lower bandwidth the id is either :
   - the PersonRef (integer) of the member if she has a userProfile
   - the unique Email key of the member otherwise
   Note that a member can belong to several companies, this is up 
   to the search functionality to interpret the id as a key to retrieve 
   all the incarnations of the person
   ======================================================================
:)
declare function custom:gen-member-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $enterprises := globals:collection('enterprises-uri')
  let $pairs :=
    map:new(
      for $p in $enterprises//Member
      let $key := $p//Email
      group by $key
      order by $p[1]/Information/Name/LastName ascending
      return
        let $ref := if (count($p) > 1) then $key else if (exists($p/PersonRef)) then $p/PersonRef else $key
        let $fn := head($p/Information/Name)/FirstName
        let $ln := head($p/Information/Name)/LastName
        return
          if (exists($ref)) then
            map:entry(
              $ref,
              concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))
              )
          else (: should not happen :)
            map:entry(
              'MISS',
              concat('MISSING\ ', $key)
            )
        )
  return
    let $ids := string-join(
      map:for-each-entry($pairs, function($key, $value) { $key })
      , ' ') 
    let $names := string-join(
      map:for-each-entry($pairs, function($key, $value) { $value })
      , ' ') 
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

declare function custom:gen-member-selector-legacy ( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in globals:collection('enterprises-uri')//Member
      let $key := $p//Email
      group by $key
      order by $p[1]/Information/Name/LastName ascending
      return
        let $ref := if (exists($p/PersonRef)) then $p[1]/PersonRef else $key
        let $fn := $p[1]/Information/Name/FirstName
        let $ln := $p[1]/Information/Name/LastName
        return
          <Name id="{$ref}">
             { concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ ')) }
          </Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Same as function form:gen-person-selector with a restriction to a given Role
   NOTE: only works with functions linked to an enterprise like LEAR or Delegate
   ======================================================================
:)
declare function custom:gen-person-with-role-selector ( $roles as xs:string+, $lang as xs:string, $params as xs:string, $class as xs:string? ) as element() {
  let $roles-ref := user:get-function-ref-for-role($roles)
  let $collection := globals:collection('persons-uri')/Person
  let $enterprise := globals:collection('enterprises-uri')/Enterprise
  let $pairs :=
    map:new(
      for $role in $collection//Role[FunctionRef = $roles-ref]
      let $p := $role/ancestor::Person
      let $ref-cie := string($role/EnterpriseRef[1]) (: takes the first one :)
      let $info := $enterprise[Id eq $ref-cie]//Member[PersonRef eq $p/Id]/Information
      let $fn := if (exists($info)) then $info/Name/FirstName else 'not found'
      let $ln := if (exists($info)) then $info/Name/LastName else 'record'
      order by $ln ascending
      return
        map:entry(
          $p/Id/text(), concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))
          )
      )
  return
    let $ids := string-join(
      map:for-each-entry($pairs, function($key, $value) { $key })
      , ' ') 
    let $names := string-join(
      map:for-each-entry($pairs, function($key, $value) { $value })
      , ' ') 
    return
      if ($ids) then
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
      else
        <xt:use types="constant" param="noxml=true;class=uneditable-input {$class}">Not available</xt:use>
};

(: ======================================================================
   Same as function form:gen-person-selector restricted to project officers
   NOTE: by convention Project Officers are members of enterprise 1 (EASME)
   ======================================================================
:)
declare function custom:gen-po-selector ( $params as xs:string, $class as xs:string? ) as element() {
  let $persons := globals:collection('persons-uri')
  let $enterprise := globals:collection('enterprises-uri')/Enterprise[Id eq '1']
  let $pairs :=
    map:new(
      for $m in $enterprise//Member
      let $p := if ($m/PersonRef) then $persons/Person[Id eq $m/PersonRef] else ()
      let $fn := $m/Information/Name/FirstName
      let $ln := $m/Information/Name/LastName
      where exists($p//Role[FunctionRef eq '2'])
      order by $ln ascending
      return
        map:entry(
          $p/Id/text(), concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))
          )
      )
  return
    let $ids := string-join(
      map:for-each-entry($pairs, function($key, $value) { $key })
      , ' ') 
    let $names := string-join(
      map:for-each-entry($pairs, function($key, $value) { $value })
      , ' ') 
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
declare function custom:gen-person-enterprise-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in globals:collection('persons-uri')//Person
      let $fn := $p/Name/FirstName
      let $ln := $p/Name/LastName
      let $pe := $p/EnterpriseRef/text()
      order by $ln ascending
      return
        let $en := if ($pe) then globals:collection('enterprises-uri')//Enterprise[Id = $pe]/Name/text() else ()
        return
          <Name id="{$p/Id/text()}">{concat(replace($ln,' ','\\ '), '\ ', replace($fn,' ','\\ '))}{if ($en) then concat('::', replace($en,' ','\\ ')) else ()}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_complement=town;{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting an enterprise
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   ======================================================================
:)
declare function custom:gen-enterprise-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('enterprise', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" i18n="{$inCache/I18n}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
    else
      let $pairs :=
          for $p in globals:collection('enterprises-uri')//Enterprise
          let $n := $p/Information/Name
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
   Generates XTiger XML 'choice' element for selecting an enterprise
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   ======================================================================
:)
declare function custom:gen-filter-enterprise-selector ( $lang as xs:string, $params as xs:string, $type as xs:string ) as element() {
      let $pairs :=
          for $p in globals:collection('enterprises-uri')//Enterprise
           let $isEntType := (enterprise:is-a($p, $type))
          let $n := $p/Information/Name
          order by $n ascending
          return
           if ($isEntType) then
             <Name id="{$p/Id/text()}">{replace($n,' ','\\ ')}{if ($p/Address/Town/text()) then concat('::', replace($p/Address/Town,' ','\\ ')) else ()}</Name>
           else ()
      return
        let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
        let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
        return (
          <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_complement=town;select2_minimumInputLength=2;{form:setup-select2($params)}"/>
          )
};

(: ======================================================================
   Will work once accessed to the ranking lists edition page
   ======================================================================
:)
declare function custom:gen-applicants-selector ( $event-id as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $pairs :=
      for $p in globals:collection('events-uri')//Event[Id eq $event-id]/Rankings//Applicant
      let $id := $p/EnterpriseRef/text()
      let $n := globals:collection('enterprises-uri')//Enterprise[Id eq $id]/Information/ShortName/text()
      order by $n ascending
      return
         <Name id="{ $id }">{replace($n,' ','\\ ')}</Name>
  return
    let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
    let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
    return
      <xt:use types="choice" values="{$ids}" i18n="{$names}" param="select2_minimumInputLength=2;{form:setup-select2($params)}"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting an enterprise town
   We do a single-pass algorithm to be sure we get same ordering between Names and Ids
   ======================================================================
:)
declare function custom:gen-town-selector ( $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup('town', $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" values="{$inCache/Values}" param="{form:setup-select2($params)}"/>
    else
      let $towns :=
        for $t in distinct-values(globals:collection('enterprises-uri')//Enterprise/Information/Address/Town/text())
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
   Generates selector for creation years 
   ======================================================================
:)
declare function custom:gen-creation-year-selector ( ) as element() {
  let $years := 
    for $y in distinct-values(globals:collection('enterprises-uri')//CreationYear)
    where matches($y, "^\d{4}$")
    order by $y descending
    return $y
  return
    <xt:use types="choice" values="{ string-join($years, ' ') }" param="select2_dropdownAutoWidth=on;select2_width=off;class=year a-control;filter=optional select2;multiple=no"/>
};

(: ======================================================================
   Generates XTiger XML 'choice' element for selecting a  Case Impact (Vecteur d'innovation)
   TODO: 
   - caching
   - use Selector / Group generic structure with a gen-selector-for( $name, $group, $lang, $params) generic function
   ======================================================================
:)
declare function custom:gen-challenges-selector-for  ( $root as xs:string, $lang as xs:string, $params as xs:string ) as element() {
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
   Tests current user is compatible with semantic role given as parameter
   TODO Implement r:secretary
   ======================================================================
:)
declare function custom:assert-semantic-role( $suffix as xs:string, $case as element(), $activity as element()? ) as xs:boolean {
  let $pid := user:get-current-person-id() 
  return
    if ($pid) then
      if ($suffix eq 'kam') then
        $pid = $case/Management/AccountManagerRef/text()
      else if ($suffix eq 'coach') then
        $pid = $activity/Assignment/ResponsibleCoachRef/text()
      else
        false()
    else
      false()
};

declare function custom:gen-short-case-title( $case as element(), $lang as xs:string ) as xs:string {
  let $ctx := $case/NeedsAnalysis/Context/InitialContextRef
  return
    if ($ctx) then
      concat(display:gen-name-for("InitialContexts", $ctx, $lang), ' - ', substring($case/CreationDate, 1, 4))
    else
      concat('... - ', substring($case/CreationDate, 1, 4))
};

declare function custom:gen-case-title( $case as element(), $lang as xs:string ) as xs:string {
  concat(
    custom:gen-enterprise-name($case/Information/ClientEnterprise/EnterpriseRef, 'en'),
    ' - ',
    custom:gen-short-case-title($case, $lang)
    )
};

declare function custom:gen-activity-title( $case as element(), $activity as element(), $lang as xs:string ) as xs:string {
  let $service := $activity/Assignment/ServiceRef
  return
    concat(
      custom:gen-enterprise-name($case/Information/ClientEnterprise/EnterpriseRef, 'en'),
      ' - ',
      if ($service) then
        concat(display:gen-name-for("Services", $service, $lang), ' - ', substring($activity/CreationDate, 1, 4))
      else
        concat('service pending - ', substring($activity/CreationDate, 1, 4))
      )
};


(: ======================================================================
   Temporary solution to filter out 'choice' plugin with 'select2' filter
   with select2_tags option when there are no value
   TODO: fix 'select2' filter in AXEL
   ====================================================================== 
:)
declare function custom:filter-select2-tags( $use as element() ) as element() {
  if ($use/@values eq '') then
    <xt:use types="input" param="class=span12"></xt:use>
  else
    $use
};

(: ======================================================================
   Returns a sequence of FunctionRef elements directly from the UserProfile
   compatible with the enterprise $cie-ref for roles scoped to the enterprise
   or returns the empty sequence
   Uses an 'enterprise-scope' cache entry of function ref with an enterprise scope
   ====================================================================== 
:)
declare function custom:get-member-roles-for( $profile as element()?, $cie-ref as xs:string, $cache as map() ) as element()* {
  if (empty($profile)) then  (: defaults to Delegate, should imply Pending access level :)
    <FunctionRef>4</FunctionRef> 
  else
    for $r in $profile//Role
    let $scope := map:get($cache, 'enterprise-scope')
    where not($r/FunctionRef = $scope) or ($cie-ref = $r/EnterpriseRef)
    return
      $r/FunctionRef
};

(: ======================================================================
   TODO: move to selector module ?
   ====================================================================== 
:)
declare function custom:get-value-for ( $name as xs:string, $label as xs:string ) as xs:string? {
  let $defs := globals:collection('global-info-uri')//Description[@Lang = 'en']/Selector[@Name eq $name]
  return
    $defs//Option[lower-case(*[local-name(.) eq $defs/@Label]) eq $label]/*[local-name(.) eq $defs/@Value]
};

(: ======================================================================
   See also 'AccessLevels' selector in global-information.xml
   FIXME: hard coded for performance 
   (an alternative would be to call custom:get-value-for('AccessLevels', 'rejected'))
   ====================================================================== 
:)
declare function custom:gen-member-access-level( $m as element(), $profile as element()? ) as xs:string {
  if ($m/PersonRef) then
    if ($profile/Blocked) then
      '4' (: blocked :)
    else if ($profile/Remote[@Name eq 'ECAS'] or $profile/Email[@Name eq 'ECAS'] or $profile/Username) then 
      '3' (: authorized :)
    else (: for debug purpose ? :)
      '99' (: unknown :)
  else
    if ($m/Rejected) then
      '2' (: rejected :)
    else
      '1' (: pending :)
};

declare function custom:gen-brief-name-for( $name as xs:string, $refs as element()*, $lang as xs:string ) as xs:string? {
  if (empty($refs)) then
    ()
  else
    let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
    return
      string-join(
        for $r in $refs
        return $defs/Option[Value eq $r]/Brief,
        ', '
        )
};

(: ======================================================================
   Filters event programs if user is an event Manager
   ======================================================================
:)
declare function custom:gen-nested-selector-for-events() as element() {
  let $staff := oppidum:get-current-user-groups() = ('admin-system', 'project-officer', 'developer', 'dg')
  let $crawler := not($staff) and oppidum:get-current-user-groups() = ('events-manager')
  let $profile := if ($crawler) then user:get-user-profile() else ()
  return
    <Selector Name="Events">
    {
      for $ev in fn:collection('/db/sites/cockpit/events')//Event
      let $prg := string($ev/Programme/@WorkflowId)
      where (not($crawler)) or $prg = $profile//Role[FunctionRef eq '5']/ProgramId
      group by $prg
      return
        <Group>
          <Value>{ $prg }</Value>
          <Name>{ fn:head($ev)/Programme/text() }</Name>
          <Selector>
          {
            for $event in $ev
            order by $event/Id ascending
            return
              <Option>
                <Value>{ $event/Id/text() }</Value>
                { 
                let $extra := $event/Information/Name/@Extra
                return
                  if ($extra) then
                    <Name>{ concat($event/Information/Name, ' : ', $event/Information/*[local-name() eq $extra]) }</Name>
                  else 
                    $event/Information/Name
                }
              </Option>
          }
          </Selector>
        </Group>
    }
    </Selector>
};

(: ======================================================================
   FIXME: how to deal with errors actually returns '/bd/null' ?
   ====================================================================== 
:)
declare function custom:get-enterprises-binary-uri( $enterprise-id as xs:string ) as xs:string {
  let $col-uri := database:gen-collection-for-key(concat($globals:binaries-uri, '/'), 'enterprise', $enterprise-id)
  return
    if (local-name($col-uri) eq 'success') then
      concat($col-uri, '/', $enterprise-id)
    else
      '/db/null'
};

(: ======================================================================
   Returns the sequence of the REST resource names to be used to display 
   thumbnails of the the photos of a given type (e.g. Photo or Logo) 
   stored within the event of the enterprise. This is actually used for
   the Confirmation form only.
   ====================================================================== 
:)
declare function custom:gen-thumbnails-for-event( $enterprise-id as xs:string, $event-id as xs:string, $type as xs:string ) as xs:string* {
  let $event-res := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $enterprise-id]//Event[Id eq $event-id]/Resources
  return
    for $res in $event-res/Resource[@Type = $type]
    let $ext := tokenize($res, '\.')[last()]
    let $col-uri := custom:get-enterprises-binary-uri($enterprise-id)
    let $file := concat(substring-before($res, '.'), '.', $ext)
    let $thumb-file := concat(substring-before($res, '.'), '-thumb.', $ext)
    return
        if (util:binary-doc-available( concat($col-uri, '/', $thumb-file) )) then
          $thumb-file
        else
          $file
};

declare function custom:gen-json-selector-for ( $sel as element()+, $lang as xs:string, $params as xs:string ) as element() {
  let $json := 
    <json>
      {
      for $g in $sel/Group
      let $val := if ($sel[1]/@Value) then string($sel[1]/@Value) else 'Value'
      return
        element { concat('_', $g/*[local-name(.) eq $val]/text()) }
        {(
        element { '__label' } { $g/Name/text() },
        for $o in $g//Option
        return
          element { concat('_', $o/*[local-name(.) eq $val]/text()) } {
            $o/Name/text()
          }
        )}
      }
    </json>
  let $res := util:serialize($json, 'method=json')
  (: trick because of JSON serialization bug, assumes at list 10 chars :)
  (:let $dedouble := concat(substring-before($res, concat("}", substring($res, 1, 10))), "}"):)
  let $filter := replace($res, '"_', '"')
  return
   <xt:use types='choice2v2' param="{$params}" values='{ $filter }'/>
};

(: ======================================================================
   Returns the Member account (i.e. Person record) or the empty sequence
   ====================================================================== 
:)
declare function custom:get-member-account( $member as element()? ) as element()? {
  if (exists($member/PersonRef)) then
    globals:collection('persons-uri')//Person[Id eq $member/PersonRef]
  else
    ()
};

(: ======================================================================
   Stub to call generic version with filter to generate sub-types
   FIXME: move to XCM
   ====================================================================== 
:)
declare function custom:gen-radio-selector-for( $name as xs:string, $lang as xs:string, $noedit as xs:boolean, $class as xs:string, $multiple as xs:string? ) as element()* {
  custom:gen-radio-selector-for($name, $lang, $noedit, $class, $multiple, ())
};

(: ======================================================================
   FIXME: move to XCM
   ====================================================================== 
:)
declare function custom:gen-radio-selector-for( $name as xs:string, $lang as xs:string, $noedit as xs:boolean, $class as xs:string, $multiple as xs:string?, $filter as xs:string* ) as element()* {
  let $defs := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $concat := if (exists($defs/@Label) and starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs/@Label, 'V+') else 'Name'
  return
     let $pairs :=
        for $p in $defs//Option[empty($filter) or not(Value = $filter)]
        let $v := $p/Value/text()
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/Name
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
        return 
          if ($noedit) then
             if ($multiple) then
               <xt:use types="choice" param="appearance=full;multiple=yes;xvalue={$multiple};class={$class} readonly;noedit=true" values="{$ids}" i18n="{$names}"/>
             else
               <xt:use types="choice" param="appearance=full;multiple=no;class={$class} readonly;noedit=true" values="{$ids}" i18n="{$names}"/>
          else if ($multiple) then
            <xt:use types="choice" param="filter=optional event;appearance=full;multiple=yes;xvalue={$multiple};class={$class}" values="{$ids}" i18n="{$names}"/>
          else
            <xt:use types="choice" param="filter=optional event;appearance=full;multiple=no;class={$class}" values="{$ids}" i18n="{$names}">{ if (exists($defs/@Default)) then string($defs/@Default) else () }</xt:use>
};

(: ======================================================================
   Similar to above with a default selected value. Do no set optional 
   event to always serialize value (to enable conditional display).
   FIXME: simplify ! merge with previous, move to XCM (done quickly !)
   ====================================================================== 
:)
declare function custom:gen-radio-selector-for( $name as xs:string, $lang as xs:string, $noedit as xs:boolean, $class as xs:string, $multiple as xs:string?, $filter as xs:string*, $default as xs:string?, $explicit-label as xs:string ) as element()* {
  let $defs := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $concat := if (exists($defs/@Label) and starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs/@Label, 'V+') else 'Name'
  return
     let $pairs :=
        for $p in $defs//Option[empty($filter) or not(Value = $filter)]
        let $v := $p/Value/text()
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/*[local-name(.) eq $explicit-label]
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
        return 
          if ($noedit) then
             if ($multiple) then
               <xt:use types="choice" param="appearance=full;multiple=yes;xvalue={$multiple};class={$class} readonly;noedit=true" values="{$ids}" i18n="{$names}">{ $default }</xt:use>
             else
               <xt:use types="choice" param="appearance=full;multiple=no;class={$class} readonly;noedit=true" values="{$ids}" i18n="{$names}">{ $default }</xt:use>
          else if ($multiple) then
            <xt:use types="choice" param="filter=event;appearance=full;multiple=yes;xvalue={$multiple};class={$class}" values="{$ids}" i18n="{$names}">{ $default }</xt:use>
          else
            <xt:use types="choice" param="filter=event;appearance=full;multiple=no;class={$class}" values="{$ids}" i18n="{$names}">{ $default }</xt:use>
};

declare function custom:set-owner-group-permissions( $path as xs:string, $user as xs:string, $group as xs:string, $perms as xs:string ) as empty() {
  let $usec := account:get-secret-user()
  let $psec := account:get-secret-password()
  return (
    system:as-user($usec, $psec, sm:chown(xs:anyURI($path), $user)),
    system:as-user($usec, $psec, sm:chgrp(xs:anyURI($path), $group)),
    system:as-user($usec, $psec, sm:chmod(xs:anyURI($path), $perms))
    )
};

(: ======================================================================
   Return true() if the given settings is defined and has same value
   ====================================================================== 
:)
declare function custom:check-settings( $module as xs:string, $key as xs:string, $values as xs:string+ ) as xs:boolean {
  let $settings := fn:doc($globals:settings-uri)/Settings/Module[Name eq $module]/Property[Key eq $key]/Value
  return exists($settings) and ($settings = $values)
};

(: ======================================================================
   Return event Processing configuration for the given enterprise
   when it exists or the empty sequence
   ====================================================================== 
:)
declare function custom:get-event-processing( $event-def as element(), $enterprise as element() ) as element()? {
  if (enterprise:is-a($enterprise, 'Investor')) then
    $event-def/Processing[@Role='investor']
  else
    $event-def/Processing[empty(@Role) or @Role eq 'beneficiary']
};

(: ======================================================================
   Convert a Country (2 letters) or ISO3CountryRef (3 letters)
   Return a Country element containing an code-3166-1-alpha-2 or 
   the empty element if no conversion or no country
   ====================================================================== 
:)
declare function custom:normalize-country( $country as element()? ) as element()? {
  if (exists($country)) then
    let $convert :=  fn:collection('/db/sites/cockpit/global-information')//Description[@Role eq 'normative']/Selector[@Name eq 'ISO3166Countries']
    return
      if (local-name($country) eq 'Country') then
        let $found := $convert//Option[code-3166-1-alpha-2 eq $country]
        let $match := if ($found) then $found else $convert//Option[code-3166-1-alpha-2/@Store eq $country]
        return
          if ($match) then <Country>{ $match/code-3166-1-alpha-3/text() }</Country> else ()
      else (: assume ISO3CountryRef :) 
        let $found := $convert//Option[code-3166-1-alpha-3 eq $country]
        let $match := if ($found) then $found else $convert//Option[code-3166-1-alpha-3/@Store eq $country]
        return
          if ($match) then <Country>{ $match/code-3166-1-alpha-3/text() }</Country> else ()
  else
    ()
};

declare function custom:gen-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $defs := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $concat := if (exists($defs/@Label) and starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs/@Label, 'V+') else 'Name'
  let $val := string($defs/@Value)
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := if ($val) then $p/*[local-name(.) eq $val] else $p/Value
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/Name
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
};

declare function custom:add-all-to-selector-for( $elem as element() ) as element() {
  <xt:use types="{$elem/@types}" values="-1 {$elem/@values}" i18n="(All) {$elem/@i18n}" param="{$elem/@param}"/>
};
declare function custom:add-all-to-selector-for-json( $elem as element() ) as element() {
let $val_add := concat("{",'"ZZ" : {"_label" : "All", "ZZZ" : "All"}, ',substring($elem/@values,2))
return 
<xt:use types="{$elem/@types}" values="{$val_add}" param="{$elem/@param}"/>
};

declare function custom:gen-selector-for-add-all ( $name as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $defs := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $concat := if (exists($defs/@Label) and starts-with($defs/@Label, 'V+')) then true() else false()
  let $label := if ($concat) then substring-after($defs/@Label, 'V+') else 'Name'
  let $val := string($defs/@Value)
  return
     let $pairs :=
        for $p in $defs//Option
        let $v := if ($val) then $p/*[local-name(.) eq $val] else $p/Value
        let $l := if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/Name
        return
           <Name id="{$v}">{(replace($l,' ','\\ '))}</Name>
    return
      let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
      let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
      return
        <xt:use types="choice" values="-1 {$ids}" i18n="(All) {$names}" param="{form:setup-select2($params)}"/>
};


(: ======================================================================
   Generate a (cached) selector for a 3 level hierarchy (see ThematicTopics)
   FIXME: actually generate a flat selector since we do not have a choice3 widget 
   ====================================================================== 
:)
declare function custom:gen-selector3-for ( $name as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup($name, $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" param="{form:setup-select2($params)}" values="{$inCache/Values}" i18n="{$inCache/I18n}"/>
    else
      let $res := 
        let $defs := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
        return
           let $pairs :=
              for $group in $defs//Group
              return
                if ($group/Selector/Option) then (: leaf Selector :)
                  for $p in $group/Selector/Option
                  return
                     <Name id="{$p/Value}">{(replace($p/Name,' ','\\ '))}</Name>
                else if (empty($group/Selector)) then (: singleton :)
                  <Name id="{$group/Value}">{(replace($group/Name,' ','\\ '))}</Name>
                else (:intermediate container :) 
                  ()
          return
            let $ids := string-join(for $n in $pairs return string($n/@id), ' ') (: FLWOR to defeat document ordering :)
            let $names := string-join(for $n in $pairs return $n/text(), ' ') (: idem :)
            return
              <xt:use types="choice" values="{$ids}" i18n="{$names}" param="{form:setup-select2($params)}"/>
      return (
        cache:update($name, $lang, $res/@values, $res/@i18n),
        $res
        )
};

(: ======================================================================
   Cached version of form:gen-selector-for
   ======================================================================
:)
declare function custom:gen-cached-selector-for ( $name as xs:string, $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup($name, $lang)
  return
    if ($inCache) then
      <xt:use hit="1" types="choice" param="{form:setup-select2($params)}" values="{$inCache/Values}">
        { 
        if ($inCache/I18n) then 
          attribute { 'i18n'} { $inCache/I18n/text() }
        else
          ()
        }
      </xt:use>
    else
      let $res := custom:gen-selector-for($name, $lang, $params)
      return (
        cache:update($name, $lang, $res/@values, $res/@i18n),
        $res
        )
};

(: ======================================================================
   Cached version of form:gen-json-selector-for
   ======================================================================
:)
declare function custom:gen-cached-json-selector-for ( $name as xs:string+, $lang as xs:string, $params as xs:string ) as element() {
  let $inCache := cache:lookup(concat( string-join($name,'-'), '/json'), $lang)
  return
    if ($inCache) then
      <xt:use hit="1"  types='choice2v2' param="{$params}" values='{$inCache/Values}'/>
    else
      let $res := custom:gen-json-selector-for( globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name = $name] , $lang, $params)
      return (
        cache:update(concat( string-join($name,'-'), '/json'), $lang, $res/@values, ()),
        $res
        )
};

(: ======================================================================
   Get alpha-3/alph2 value from a Country (2 letters) or ISO3CountryRef (3 letters)
   If the code is incorrect return it in <error> element
   ====================================================================== 
:)
declare function custom:get-country-code-value( $countryID as xs:string, $value as xs:string ) as element()? {
  let $convert :=  fn:collection('/db/sites/cockpit/global-information')//Description[@Role eq 'normative']/Selector[@Name eq 'ISO3166Countries']
  return 
    let $found := ($convert//Option[code-3166-1-alpha-2 eq $countryID], $convert//Option[code-3166-1-alpha-3 eq $countryID],$convert//Option[code-3166-1-alpha-2[@Store eq $countryID]],$convert//Option[code-3166-1-alpha-3[@Store eq $countryID]])[1]
    return
      if ($found) then
        if ($value eq 'iso2') then 
          $found/code-3166-1-alpha-2
        else
          $found/code-3166-1-alpha-3
      else <error>{ $countryID }</error>
};


(: ======================================================================
   Get alpha-3/alph2 value from a Country (2 letters) or ISO3CountryRef (3 letters)
   If the code is incorrect return it in <error> element
   Be careful : Use @Store first ! It's a workaround for an old countries selector
   ====================================================================== 
:)
declare function custom:get-country-code-value-store( $countryID as xs:string, $value as xs:string ) as element()? {
  let $convert :=  fn:collection('/db/sites/cockpit/global-information')//Description[@Role eq 'normative']/Selector[@Name eq 'ISO3166Countries']
  return 
    let $found := ($convert//Option[code-3166-1-alpha-2 eq $countryID], $convert//Option[code-3166-1-alpha-3 eq $countryID],$convert//Option[code-3166-1-alpha-2[@Store eq $countryID]],$convert//Option[code-3166-1-alpha-3[@Store eq $countryID]])[1]
    return
      if ($found) then
        if ($value eq 'iso2') then 
          if (exists($found/code-3166-1-alpha-2/@Store)) then
            <code-3166-1-alpha-2>{ string($found/code-3166-1-alpha-2/@Store) }</code-3166-1-alpha-2>
          else
            $found/code-3166-1-alpha-2
        else
          if (exists($found/code-3166-1-alpha-3/@Store)) then
            <code-3166-1-alpha-3>{ string($found/code-3166-1-alpha-3/@Store) }</code-3166-1-alpha-3>
          else
            $found/code-3166-1-alpha-3
      else <error>{ $countryID }</error>
};

(: ======================================================================
   Get alpha-3/alph2 value from a Country (2 letters) or ISO3CountryRef (3 letters)
   If the code is incorrect return it in error string
   ====================================================================== 
:)
declare function custom:get-country-adress( $informationElem as element(), $value as xs:string ) as  xs:string {
  if (exists($informationElem/Address/Country)) then
        let $country := custom:get-country-code-value($informationElem/Address/Country/text(), $value)
        return
          if (exists($country) and (local-name($country) ne 'error')) then $country/text() 
          else 'error'
      else if (exists($informationElem/Address/ISO3CountryRef)) then
        let $country := custom:get-country-code-value($informationElem/Address/ISO3CountryRef/text(), $value)
        return
          if (exists($country) and (local-name($country) ne 'error')) then $country/text() 
          else 'error'                        
      else 'error'
};
(: ======================================================================
   Get the the Alt element with @variant=$variant using the reference ($ref)
   
   Parameter:
   - $name: Selector name
   - $ref: reference (Value selected)
   - $variant: Corresponding value for a target. 
   - return empty element if no option or if the option is skipped
   - return Option/Name if the option exist but whitout variant
   
   For instance: "Sizes" selecter for EIC Community (variant number "1")
   In enterprises, $ref equal SizeRef element
   If SizeRef=1 then Return Alt @Variant="1"
   
   <Option>
      <Value>1</Value>
      <!-- Variant="1" -->
      <Alt Variant="1">micro</Alt>
      <Name>Micro (1-9 employees)</Name>
   </Option>

   <Option Skip="1"> --> Skipped for Variant 1
      <Value>5</Value>
      <Alt Variant="1">other</Alt>
      <Name>Other</Name>
   </Option>
   ====================================================================== 
:)
declare function custom:get-selector-variant-value($name as xs:string, $ref as element()?, $variant as xs:string, $lang ) as element()? {
  let $selector  := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
  return
   if (exists($ref)) then
    let $found :=  $selector//Option[Value/text() eq $ref/text()]
    let $option := if ($found) then $found else ()
    return
      if (exists($option) and not($option[@Skip eq $variant])) then
        let $alt := $option/Alt[@Variant eq $variant]
        return
          if (exists($alt)) then $alt else $option/Name
      else
      ()
   else
   ()
};

(: ======================================================================
   Get the the Value element of an option using the $label
   
   Parameter:
   - $name: Selector name
   - $label: Matching string - with Name element 
   - return empty element if no option matching
    ====================================================================== 
:)  
declare function custom:get-selector-value($name as xs:string, $label as xs:string, $lang  as xs:string) as element()? {
  let $selector  := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $found :=  $selector//Option[Name/text() eq $label]
  let $option := if ($found) then $found else ()
  return
    if (exists($option)) then
      $option/Value
    else
    () 
};

(: ======================================================================
   Get the the Name element of an option using the $Id
   
   Parameter:
   - $name: Selector name
   - $id: Matching string - with Id element 
   - return empty element if no option matching
    ====================================================================== 
:)  
declare function custom:get-selector-name($name as xs:string, $Id as xs:string, $lang  as xs:string) as element()? {
  let $selector  := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $found :=  $selector//Option[(Id/text() eq $Id) or (Code/text() eq $Id)]
  let $option := if ($found) then $found else ()
  return
    if (exists($option)) then
      $option/Name
    else
    () 
};

(: ======================================================================
   Get the the Value element of an option using the $label
   
   Parameter:
   - $name: Selector name
   - $value: Matching string - with value element 
   - return empty element if no option matching
    ====================================================================== 
:)  
declare function custom:get-selector-label($name as xs:string, $value as xs:string, $lang  as xs:string) as element()? {
  let $selector  := globals:collection('global-info-uri')//Description[@Lang = $lang]//Selector[@Name eq $name]
  let $found :=  $selector//Option[Value/text() eq $value]
  let $option := if ($found) then $found else ()
  return
    if (exists($option)) then
      $option/Name
    else
    ()
};

(: ======================================================================
   Generates selector for realms
   ======================================================================
:)
declare function custom:gen-realm-selector ( $params as xs:string ) as element() {
let $rlms :=
      for $r in fn:doc(oppidum:path-to-config('security.xml'))/Realms/Realm[@Name ne 'EXIST']
      let $n := string($r/@Name)
      order by $n ascending
      return $n
  return
    <xt:use types="choice" values="{ string-join($rlms, ' ') }" param="{form:setup-select2($params)}"/>
};

(: ======================================================================
   Return the list of function references for roles requiring scope $scope
   ====================================================================== 
:)
declare function custom:get-roles-in-scope( $scope as xs:string ) as xs:string* {
  globals:collection('global-info-uri')//Description[@Role = 'normative']/Selector[@Name eq 'Functions']//Option[@Scope eq $scope][empty(@AdminPanel) or (@AdminPanel ne 'static')]/Value
};

