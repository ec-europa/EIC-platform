xquery version "3.1";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <sire@oppidoc.fr>

   Utility to deploy the application after a code update on file system with git

   You can use it for initial deployment or for maintenance updates,
   do not forget to separately restore the application data and/or system collection (users accounts)

   PRE-CONDITIONS :
   - scripts/bootstrap.sh has been executed first (to install mapping.xml inside database)
   - must be called from the server (e.g.: using curl or wget)
   - admin password must be provided as a pwd parameter

   SYNOPSIS :
   curl [or wget -O-] http:127.0.0.1:[PORT]/exist/projects/cctracker/admin/deploy?pwd=[PASSWORD]&t=[TARGETS]

   TARGETS
   - all : deploy all command, use it right after bootstrap.sh to create initial database
           can be used on a restored database since it should not overwrite essential files (untested)
   - users : create "demo" user (only works with the persons.xml bootstrap persons records, may be useless 
           on a restored database)
   - sites : create part of collection structure
   - config : application configuration (except environment dependent ones settings.xml and services.xml)
   - data : global information data (except regions which must be bootstrapped with all)
   - mesh : application mesh files
   - templates : application XTiger templats
   - forms : generate all formulars with supergrid (see $formulars in this script)
   - caches : reset cache.xml
   - debug : reset debug.xml
   - indexes configuration : configuration for indexes, you must recompute indexes aright after
           or you may not be able to access data
   - services : 3rd party services (feedback questionnaires), feedback application must be running 
          and services.xml 
   - stats : stats configuration to run statistics
   - timesheets : ?
   - questionnaires : ?
   - jobs : code for nightly jobs that must be loaded inside database for execution by the scheduler
          you need to manually schedule the job in conf.xml and restart database)
   - policies : set permissions on all database (must be applied after every thing else)

   JOBS:
   curl -i "http://localhost:[PORT]/exist/projects/cctracker/admin/deploy?pwd=[PASSWORD]&t=jobs[,policies]"
   - in addition you MUST copy /db/www/oppidum/lib/util.xqm to database

   POST-INSTALLATION :
   - check Sudoer user from settings exists or create it manually (see modules/users/account.xqm)
     or create it using platform overarching depot deploy command
   
   TRICK:
   You can generate $formulars by executing in sandbox :
   let $n := fn:doc(concat('file://', system:get-exist-home(), '/webapp/projects/cctracker/formulars/_register.xml'))
   return string-join(for $i in $n//Form return substring-after($i, 'forms/'), '+')

   November 2014 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace install = "http://oppidoc.com/oppidum/install" at "../../oppidum/lib/install.xqm";
import module namespace sg = "http://coaching.ch/ns/supergrid" at "../modules/formulars/install.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../lib/services.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../oppidum/lib/compat.xqm";
import module namespace codegen = "http://oppidoc.com/ns/cctracker/codegen" at "../modules/reports/codegen.xqm";

declare option exist:serialize "method=xml media-type=text/html indent=yes";

declare variable $formulars := "enterprise+enterprise-search+region+region-search+person+person-search+service+coach-search+project-information+case-information+managing-entity+case-management+needs-analysis+coaching-assignment+funding-request+opinions+funding-decision+coach-contract+final-report+final-report-approval+closing+evaluation+evaluations+sme-feedback+kam-feedback+position+notification+email+profile+remote+account+stats-cases+stats-activities+stats-kpi";

declare variable $policies := <policies xmlns="http://oppidoc.com/oppidum/install">
  <!-- Users -->
  <user name="demo" groups="users admin-system" password="test"/>
  <!-- Policies -->
  <policy name="admin" owner="admin" group="users" perms="rwxr-xr-x"/>
  <policy name="any-up" owner="admin" group="users" perms="rwxr-xr-x"/>
  <policy name="users" owner="admin" group="users" perms="rwxrwxr-x"/>
  <policy name="open" owner="admin" group="users" perms="rwxrwxrwx"/>
  <policy name="strict" owner="admin" group="users" perms="rwxrwx---"/>
  <policy name="guest" owner="admin" group="users" perms="rwxr-xr-x"/>
</policies>;

(: ======================================================================
   TODO: 
   - fix Oppidum inherit eq 'true' test in install-policies
   - invent
     <collection name="/db/sites/cctracker/checks" policy="open" inherit-policy="users"/> 
     to set collection policy different thatn its resources policies
   ======================================================================
:)

declare variable $code := <code xmlns="http://oppidoc.com/oppidum/install">
  <collection name="/db/www/cctracker" policy="admin" inherit="yes"/>
  <group name="batch" incl="all">
    <collection name="/db/batch" policy="strict" inherit="yes"/>
  </group>
  <group name="globals" incl="all">
    <collection name="/db/www/excm/config">
      <files pattern="config/globals.xml"/>
    </collection>
  </group>
  <group name="analytics" incl="all">
    <collection name="/db/analytics/cctracker" policy="users" inherit="yes"/>
  </group>
  <group name="caches" incl="all">
    <collection name="/db/caches/cctracker" policy="open" inherit="yes">
      <files pattern="caches/cache.xml"/>
    </collection>
  </group>
  <group name="debug" incl="all">
    <collection name="/db/debug" policy="open" inherit="yes">
      <files pattern="debug/debug.xml"/>
      <files pattern="debug/login.xml"/>
    </collection>
  </group>
  <group name="config" mandatory="true">
    <collection name="/db/www/cctracker/config" policy="any-up" inherit="yes">
      <files pattern="config/mapping.xml"/>
      <files pattern="config/modules.xml"/>
      <files pattern="config/skin.xml"/>
      <files pattern="config/errors.xml"/>
      <files pattern="config/messages.xml"/>
      <files pattern="config/dictionary.xml"/>
      <files pattern="config/proxies.xml"/>
      <files pattern="config/security.xml"/>
      <!-- next 2 files are deployed with platform depot -->
      <!--<files pattern="config/settings.xml"/>-->
      <!--<files pattern="config/services.xml"/>-->
      <files pattern="config/application.xml"/>
      <files pattern="config/database.xml"/>
      <files pattern="modules/stats/stats.xml"/>
      <files pattern="config/variables.xml"/>
      <files pattern="config/reports.xml"/>
      <files pattern="modules/alerts/checks.xml"/>
    </collection>
  </group>
  <group name="reports">
    <collection name="/db/www/cctracker/config">
      <files pattern="config/reports.xml"/>
    </collection>
    <collection name="/db/sites/cctracker/reports" policy="users" inherit="yes">
      <files pattern="data/reports/meta.xml"/>
    </collection>
  </group>
  <group name="mesh" mandatory="true">
    <collection name="/db/www/cctracker/mesh">
      <files pattern="mesh/*.html"/>
    </collection>
  </group>
  <group name="templates" mandatory="true" incl="all">
    <collection name="/db/www/cctracker/mesh">
      <files pattern="templates/annexe.xhtml"/>
      <files pattern="templates/stage-search.xhtml"/>
    </collection>
    <collection name="/db/www/cctracker/templates" policy="admin" inherit="yes">
      <files pattern="templates/*.xml"/>
    </collection>
  </group>
  <group name="indexes" incl="all">
    <collection name="/db/system/config/db/sites/cctracker/enterprises">
      <files pattern="indexes/enterprises/collection.xconf" type="text/xml"/>
    </collection>
    <collection name="/db/system/config/db/sites/cctracker/persons">
      <files pattern="indexes/persons/collection.xconf" type="text/xml"/>
    </collection>
    <collection name="/db/system/config/db/www/cctracker/config">
      <files pattern="indexes/config/collection.xconf" type="text/xml"/>
    </collection>
    <collection name="/db/system/config/db/sites/cctracker/projects">
      <files pattern="indexes/projects/collection.xconf" type="text/xml"/>
    </collection>
    <collection name="/db/system/config/db/sites/cctracker/reports">
      <files pattern="indexes/reports/collection.xconf" type="text/xml"/>
    </collection>
  </group>
  <group name="sites" incl="all">
    <collection name="/db/sites/cctracker" policy="users" inherit="yes"/>
    <collection name="/db/sites/cctracker/cases" policy="users" inherit="yes"/>
    <collection name="/db/sites/cctracker/checks" policy="strict" inherit="yes"/>
    <collection name="/db/sites/cctracker/reports" policy="strict" inherit="yes"/>
    <collection name="/db/sites/cctracker/reminders" policy="strict" inherit="yes"/>
  </group>
  <group name="jobs" incl="all">
    <!-- oppidum -->
    <collection name="/db/www/oppidum/lib" policy="guest" inherit="yes">
      <files pattern="oppidum:lib/util.xqm"/>
      <files pattern="oppidum:lib/compat.xqm"/>
    </collection>
    <!-- cctracker -->
    <collection name="/db/sites/cctracker/checks" policy="open" inherit="yes"/>
    <collection name="/db/sites/cctracker/reports" policy="open" inherit="yes"/>
    <collection name="/db/sites/cctracker/reminders" policy="open" inherit="yes"/>
    <collection name="/db/www/cctracker/lib" policy="guest" inherit="yes">
      <files pattern="lib/globals.xqm"/>
      <files pattern="lib/display.xqm"/>
      <files pattern="lib/check.xqm"/>
      <files pattern="lib/mail.xqm"/>
      <files pattern="lib/media.xqm"/>
      <files pattern="lib/services.xqm"/>
      <files pattern="lib/access.xqm"/>
      <files pattern="lib/ajax.xqm"/>
      <files pattern="lib/util.xqm"/>
      <files pattern="lib/excel.xqm"/>
      <files pattern="lib/map.xqm"/>
    </collection>
    <collection name="/db/www/cctracker/modules/reports" policy="guest" inherit="yes">
      <files pattern="modules/reports/report.xqm"/>
      <files pattern="modules/reports/job.xql"/>
    </collection>
    <collection name="/db/www/cctracker/modules/alerts" policy="guest" inherit="yes">
      <files pattern="modules/alerts/check.xqm"/>
      <files pattern="modules/alerts/job.xql"/>
    </collection>
    <collection name="/db/www/cctracker/modules/workflow" policy="guest" inherit="yes">
      <files pattern="modules/workflow/alert.xqm"/>
      <files pattern="modules/workflow/workflow.xqm"/>
    </collection>
    <collection name="/db/www/cctracker/modules/activities" policy="guest" inherit="yes">
      <files pattern="modules/activities/activity.xqm"/>
    </collection>
    <collection name="/db/www/cctracker/modules/cases" policy="guest" inherit="yes">
      <files pattern="modules/cases/case.xqm"/>
    </collection>
    <collection name="/db/www/cctracker/modules/users" policy="guest" inherit="yes">
      <files pattern="modules/users/account.xqm"/>
    </collection>
  </group>
  <group name="timesheets" incl="all">
    <collection name="/db/sites/cctracker/timesheets" policy="strict" inherit="yes"/>
  </group>
  <group name="questionnaires" incl="all">
    <collection name="/db/www/cctracker/formulars" policy="strict" inherit="yes">
      <files pattern="formulars/sme-feedback.xml"/>
      <files pattern="formulars/kam-feedback.xml"/>
    </collection>
  </group>
  <group name="stats" incl="all">
    <collection name="/db/www/cctracker/config">
      <files pattern="modules/stats/stats.xml"/>
    </collection>
    <collection name="/db/www/cctracker/formulars">
      <files pattern="formulars/stats.xml"/>
      <files pattern="formulars/stats-cases.xml"/>
      <files pattern="formulars/stats-activities.xml"/>
      <files pattern="formulars/stats-kpi.xml"/>
    </collection>
  </group>
  <group name="data" incl="all">
    <!-- DO NOT include regions.xml which is end-user generated -->
    <collection name="/db/sites/cctracker/global-information">
      <files pattern="data/global-information/countries-en.xml"/>
      <files pattern="data/global-information/email.xml"/>
      <files pattern="data/global-information/global-information.xml"/>
      <files pattern="data/global-information/languages-en.xml"/>
      <files pattern="data/global-information/naces-en.xml"/>
      <files pattern="data/global-information/reuters-en.xml"/>
      <files pattern="data/global-information/eic-panels.xml"/>
      <files pattern="data/global-information/fet-ria-topics.xml"/>
      <files pattern="data/global-information/programs.xml"/>
    </collection>
  </group>
  <!-- special group only loaded  with ?target=all if not already loaded 
       FIXME: could be directly implemented inside install module -->
  <group name="bootstrap" incl="no">
    <!--collection name="/db/sites/cctracker/global-information">
      <files pattern="data/global-information/regions.xml"/>
    </collection-->
    <!--collection name="/db/sites/cctracker/regions">
      <files pattern="data/regions/regions.xml"/>
    </collection-->
    <collection name="/db/sites/cctracker/enterprises">
      <files pattern="data/enterprises/enterprises.xml"/>
    </collection>
    <!--collection name="/db/sites/cctracker/persons">
      <files pattern="data/persons/persons.xml"/>
    </collection-->
    <collection name="/db/sites/cctracker/persons">
      <files pattern="data/persons/remotes.xml"/>
    </collection>
    <collection name="/db/www/cctracker/config">
      <files pattern="config/settings.xml"/>
    </collection>
    <collection name="/db/www/cctracker/config">
      <files pattern="config/services.xml"/>
    </collection>
  </group>
   <group name="nuts" incl="all">
    <collection name="/db/sites/nuts" policy="any-up" inherit="yes"/>
  </group>
</code>;


(: ======================================================================
   Adapter to call install policies on a single group
   ====================================================================== 
:)
declare function local:install-group-policy( $target as xs:string ) as element()*
{
  let $specs := <code xmlns="http://oppidoc.com/oppidum/install">
                  { $code/install:group[@name = $target] }
                </code>
  return
    install:install-policies($target, $policies, $specs, ())
};

(: ======================================================================
   TODO:
   restore
   <Allow>
       <Category>account</Category>
       <Category>workflow</Category>
       <Category>action</Category>
   </Allow>
   into Media element in settings.xml
   ======================================================================
:)
declare function local:do-post-deploy-actions ( $dir as xs:string,  $targets as xs:string*, $base-url as xs:string, $mode as xs:string ) {
  (: terminates globals.xml installation usually once after bootstrap.sh - no -uri convention ! :)
  if ('globals' = $targets) then
    for $global in fn:doc($globals:globals-uri)//Global[not(Value)]
    let $value := if (exists($global/Eval)) then string($global/Eval) else concat('$globals:', $global/Key, '-uri')
    return (
      update insert <Value>{ util:eval($value) }</Value> into $global,
      if (exists($global/Eval)) then
        update delete $global/Eval
      else
        (),
      <p>replacing { $value } into globals</p>
      )
  else
    (),
  if ('config' = $targets) then
    let $mapping := fn:doc('/db/www/cctracker/config/mapping.xml')/site
    let $settings := fn:doc('/db/www/cctracker/config/settings.xml')/Settings
    return
      (
      update value $mapping/@mode with $mode,
      <p>Set mode to { $mode }</p>,
      if ($mode = 'prod') then (
        update value $mapping/@supported with 'login logout',
        <p>Restrict root mapping supported actions to 'login logout'</p>
        )
      else
        <p>Did not restrict root mapping supported actions set to { string($mapping/@supported) }</p>,
      if  (not(exists($mapping/@base-url)) and $mode = ('test', 'prod')) then
        (
        update insert attribute { 'base-url' } {'/'} into $mapping,
        <p>Set attribue base-url to '/'</p>
        )
      else (
        if (exists($mapping/@base-url)) then
          update delete $mapping/@base-url
        else
          (),
        <p>Removed attribute base-url for '{ $mode }'</p>
        ),
      if (($settings/SMTPServer eq '!localhost') and $mode = 'prod') then
        (
        update value $settings/SMTPServer with 'localhost',
        <p>Changed SMTP Server to "localhost" to activate mail</p>
        )
      else if (($settings/SMTPServer eq 'localhost') and $mode = ('dev', 'test')) then
        (
        update value $settings/SMTPServer with '!localhost',
        <p>Changed SMTP Server to "!localhost" to inactivate mail for '{ $mode }'</p>
        )
      else
        <p>SMTP Server is configured to "{string($settings/SMTPServer)}"</p>
      )
  else
    ()
};

declare function local:deploy ( $dir as xs:string,  $targets as xs:string*, $base-url as xs:string, $mode as xs:string ) {
  (
  let $itargets := $targets[not(. = ('users', 'policies', 'forms', 'services'))]
  return
    if (count($itargets) > 0) then
      <target name="{string-join($itargets,', ')}">
        {  
        install:install-targets($dir, $itargets, $code, ()),
        for $t in (('timesheets', 'analytics'))
        return
          if ($t = $targets) then
            <policy>{ install:install-policies($t, $policies, $code, ())}</policy>
          else
            ()
      }
      </target>
    else
      (),
  if ('config' = $targets) then 
    (: xdb:set-resource-permissions('/db/www/cctracker/config', 'settings.xml', 'admin', 'admin-system', 492) (: "rwxr-x-r--" :) :)
    (:compat:set-owner-group-permissions(concat('/db/www/cctracker/config', '/', 'settings.xml'), 'admin', 'users', 'rwxr-xr--') :)
    <target name="config (policies)">{ local:install-group-policy('config') }</target>
  else
    (),
  if ('forms' = $targets) then
    <target name="forms" base-url="{$base-url}">{ sg:gen-and-save-forms($formulars, $base-url) }</target>
  else
    (),
  if ('services' = $targets) then
    (<target name="services">{ services:deploy($dir) }</target>,
	install:install-targets($dir, ('questionnaires'), $code, ()))
  else
    (),
  (: install policies on jobs to be sure :)
  if ('jobs' = $targets) then
    <target name="jobs (policies)">{ local:install-group-policy('jobs') }</target>
  else
    (),
  (: must be done after other targets that could create collections/resources :)
  if ('policies' = $targets) then
    <target name="policies">{ install:install-policies(('caches', 'debug', 'sites', 'jobs', 'nuts'), $policies, $code, ())}</target>
  else
    (),
  (: must be done after other targets that could create colletions/resources :)
  if (('indexes', 'reindex') = $targets) then (
    <p>reindexing /db/sites/cctracker collections { xdb:reindex('/db/sites/cctracker') }</p>,
    <p>reindexing /db/www/cctracker collections { xdb:reindex('/db/www/cctracker') }</p>
    )
  else
    (),
  (: must be done after other targets that could update $globals:persons-uri to print warning :)
  if ('users' = $targets) then
    <target name="users">
      { 
      let $groups := sm:list-groups()
      let $group := $groups[. = ('users')]
        return 
            if ($group eq "users") then
                <li> Not Created group { 'users' } because it already exists</li>
            else
                <li>Created group { sm:create-group('users'), 'users' }</li>,
      install:install-users($policies),
      for $user in $policies/install:user/string(@name)
      return 
        if (empty(fn:collection($globals:persons-uri)//Person[UserProfile/Username eq $user])) then
          <p>creating user <span style="color:red">{ $user }</span> useless because s/he is not associated to any user profile in database</p>
        else
          ()
      }
    </target>
  else
    (),
  if ('reports' = $targets) then (
    <p>generating { codegen:deploy-reports() }</p>,
    <p>{ local:install-group-policy('reports') }</p>
    )
  else 
    (),
  local:do-post-deploy-actions($dir, $targets, $base-url, $mode)
  )
};

(: ======================================================================
   Special all target implementation : rewrites to a combination 
   of other targets
   ====================================================================== 
:)
declare function local:all ( $dir as xs:string,  $base-url as xs:string, $mode as xs:string ) {
  let $targets := distinct-values((
    $code/install:group[@mandatory eq 'true']/string(@name),
    $code/install:group[@incl eq 'all']/string(@name),
    'forms',
    'policies',
    'users',
    'reports'
    ))
  return (
    <p>'all' target bootstrapping :</p>,
    <ul>
      {
      for $c in $code/install:group[@name eq 'bootstrap']/install:collection
      let $col := $c/string(@name)
      let $file := tokenize($c/install:files/string(@pattern), '/')[last()]
      return
        if (fn:doc-available(concat($col, '/', $file))) then
          <li>{ $col } : { $file } already exists, does not deploy it</li>
        else
          install:install-collection($dir, $c, ())
      }
    </ul>,
    <p>Now executing 'all' targets rewritten to => { string-join($targets, ',') }</p>,
    local:deploy($dir, $targets, $base-url, $mode)
    )
};

(: ======================================================================
   Utility to summarize list of possible targets
   ====================================================================== 
:)
declare function local:gen-targets() {
  string-join(
    (
    'all',
    $code/install:group[empty(@incl) or @incl != 'no']/@name,
    'forms',
    'users',
    'policies'
    ), ','
  )
};

let $dir := install:webapp-home(concat(globals:app-folder(), "/cctracker"))
let $pwd := request:get-parameter('pwd', ())
let $mode := request:get-parameter('m', fn:doc('/db/www/cctracker/config/mapping.xml')/site/@mode)
let $targets := tokenize(request:get-parameter('t', ''), ',')
let $host := request:get-header('Host')
let $cmd := request:get-attribute('oppidum.command')
return
  if (starts-with($host, 'localhost') or starts-with($host, '127.0.0.1')) then
    if ($pwd and (count($targets) > 0)) then
      if ($targets = 'all') then
        if (count($targets) eq 1) then
      <results count="{count($targets)}">
        <dir>{$dir}</dir>
            { system:as-user('admin', $pwd, local:all($dir, $cmd/@base-url, $mode)) }
          </results>
        else
          <results>all target cannot be combined with others</results>
      else
        <results count="{count($targets)}">
          <dir>{$dir}</dir>
        { system:as-user('admin', $pwd, local:deploy($dir, $targets, $cmd/@base-url, $mode)) }
      </results>
    else
      <results>Usage : deploy?t={ local:gen-targets() }&amp;pwd=[ADMIN PASSWORD]&amp;m=(dev | test | [prod])</results>
  else
    <results>This script can be called only from the server</results>
