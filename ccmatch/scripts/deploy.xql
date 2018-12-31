xquery version "3.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <sire@oppidoc.fr>

   Utility to deploy the application after eXist-DB installation (bootstrap),
   database restoration (restore) and or code update on file system with git (switch)

   You can use it for releasing 

   PRE-CONDITIONS :
   - scripts/bootstrap.sh has been executed first (to install mapping.xml inside database)
   - must be called from the server (e.g.: using curl or wget)
   - admin password must be provided as a pwd parameter

   SYNOPSIS :
   curl -i [or wget -O-] http:127.0.0.1:[PORT]/exist/projets/ccmatch/admin/deploy?pwd=[PASSWORD]&t=[TARGETS]

   TARGETS : bootstrap, restore, switch (or specific target)

   POST-INSTALLATION :
   - configure Sudoer and Surrogate in settings (usually done with platform/deploy&pwd=[PASSWORD] command)
   
   TRICK:
   You can generate $formulars by executing in sandbox :
   let $n := fn:doc(concat('file://', system:get-exist-home(), '/webapp/projets/ccmatch/formulars/_register.xml'))
   return string-join(for $i in $n//Form return substring-after($i, 'forms/'), '+')

   May 2016 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace install = "http://oppidoc.com/oppidum/install" at "../../oppidum/lib/install.xqm";
import module namespace deploy = "http://oppidoc.com/ns/deploy" at "../../excm/lib/deploy.xqm";
import module namespace sg = "http://coaching.ch/ns/supergrid" at "../modules/formulars/install.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../lib/services.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";

declare option exist:serialize "method=html media-type=text/html indent=yes";

declare variable $formulars := "sme-profile+coach-contact+coach-experiences+coach-competences+search-criteria+search-user+account+confirm+account-availabilities+account-visibilities+coach-registration+login+host-contact-persons+host-account+host-comments+stats-coaches";

declare variable $policies := <policies xmlns="http://oppidoc.com/oppidum/install">
  <!-- Policies -->
  <policy name="strict-collection" owner="admin" group="users" perms="rwxr-xr-x"/>
  <policy name="strict-document" owner="admin" group="users" perms="rw-r--r--"/>
  <policy name="strict-code" owner="admin" group="users" perms="rwxr-xr-x"/>
  <policy name="unrestricted-collection" owner="admin" group="users" perms="rwxrwxrwx"/>
  <policy name="unrestricted-document" owner="admin" group="users" perms="rw-rw-rw-"/>
  <policy name="guest-can-open-collection" owner="admin" group="users" perms="rwxrwxr-x"/>
  <policy name="only-user-can-write-document" owner="admin" group="users" perms="rw-rw-r--"/>
</policies>;

(: =====================================================================
   NOTE: The $code MUST define all application collections
         and their related permissions
   ===================================================================== 
:)
declare variable $code := <code xmlns="http://oppidoc.com/oppidum/install">
  <targets>
    <set name="bootstrap"><incl>restore</incl><incl>switch</incl><target>policies</target></set>
    <set name="restore"><incl>switch</incl><target>policies</target></set>
    <set name="*"><incl>forms</incl></set>
    <target name="forms"/>
    <target name="cross-search"/>
    <target name="policies"/>
    <target name="reindex"/>
  </targets>
  <collection name="/db/www/ccmatch" collection-policy="strict-collection" inherit="collection"/>
  <collection name="/db/sites/ccmatch" collection-policy="guest-can-open-collection" inherit="collection"/>
  <!-- ***************
       ** bootstrap **
       *************** -->
  <group name="globals" incl="bootstrap">
    <collection name="/db/www/excm/config" collection-policy="strict-collection" resource-policy="strict-document" inherit="yes">
      <files pattern="config/globals.xml"/>
    </collection>
  </group>
  <group name="security" incl="bootstrap">
    <!-- don't forget to deploy platform to reset Surrogate password... -->
    <collection name="/db/www/ccmatch/config">
      <files pattern="config/security.xml"/>
    </collection>
  </group>
  <group name="debug" incl="bootstrap">
    <collection name="/db/debug" collection-policy="unrestricted-collection" resource-policy="unrestricted-document" inherit="yes">
      <files pattern="excm:data/debug/debug.xml"/>
      <files pattern="excm:data/debug/login.xml"/>
    </collection>
  </group>
  <group name="analytics" incl="bootstrap">
    <collection name="/db/analytics/ccmatch" collection-policy="unrestricted-collection" resource-policy="unrestricted-document"  inherit="yes"/>
  </group>
  <group name="nonces" incl="bootstrap">
    <collection name="/db/nonces" collection-policy="unrestricted-collection" resource-policy="unrestricted-document" inherit="yes">
      <files pattern="data/nonces/nonces.xml"/>
    </collection>
  </group>
  <group name="hosts" incl="bootstrap">
    <collection name="/db/sites/ccmatch/hosts" collection-policy="guest-can-open-collection" resource-policy="only-user-can-write-document" inherit="yes"/>
  </group>
  <group name="persons" incl="bootstrap">
    <collection name="/db/sites/ccmatch/persons" collection-policy="guest-can-open-collection" resource-policy="only-user-can-write-document" inherit="yes"/>
  </group>
  <group name="cv" incl="bootstrap">
    <collection name="/db/sites/ccmatch/cv" collection-policy="guest-can-open-collection" resource-policy="only-user-can-write-document" inherit="yes"/>
  </group>
  <group name="photos" incl="bootstrap">
    <collection name="/db/sites/ccmatch/photos" collection-policy="guest-can-open-collection" resource-policy="only-user-can-write-document" inherit="yes"/>
  </group>
  <group name="demo" incl="bootstrap">
    <collection name="/db/sites/ccmatch/persons/0000">
      <files pattern="data/persons/**/*.xml"/>
    </collection>
  </group>
  <!-- **************
       ** restore  **
       ************** -->
  <group name="mesh" incl="restore">
    <collection name="/db/www/ccmatch/mesh" collection-policy="strict-collection" resource-policy="strict-document" inherit="yes">
      <files pattern="mesh/*.html"/>
      <files pattern="mesh/*.xhtml"/>
    </collection>
  </group>
  <group name="data" incl="restore">
    <collection name="/db/sites/ccmatch/global-information" collection-policy="strict-collection" resource-policy="only-user-can-write-document" inherit="yes">
      <files pattern="data/global-information/*.xml"/>
    </collection>
  </group>  
  <group name="feeds" incl="restore">
    <collection name="/db/www/ccmatch/config">
      <files pattern="modules/feeds/feeds.xml"/>
    </collection>
  </group>
  <group name="stats" incl="restore">
    <collection name="/db/www/ccmatch/config">
      <files pattern="modules/stats/stats.xml"/>
    </collection>  
    <collection name="/db/www/ccmatch/formulars" collection-policy="strict-collection" resource-policy="strict-document" inherit="yes">
      <files pattern="formulars/stats.xml"/>
      <files pattern="formulars/stats-coaches.xml"/>
    </collection>
  </group>
  <!-- ************
       ** switch **
       ************ -->
  <group name="config" incl="switch">
    <collection name="/db/www/ccmatch/config" collection-policy="strict-collection" resource-policy="strict-document" inherit="yes">
      <files pattern="config/dictionary.xml"/>
      <files pattern="config/errors.xml"/>
      <files pattern="config/mapping.xml"/>
      <files pattern="config/messages.xml"/>
      <files pattern="config/modules.xml"/>
      <files pattern="config/skin.xml"/>
      <!-- next ones in platform depot... -->
      <!-- <files pattern="config/services.xml"/> -->
      <!-- <files pattern="config/settings.xml"/> -->
    </collection>
  </group>
  
   <group name="templates" incl="switch">
    <collection name="/db/www/ccmatch/templates" policy="admin" inherit="yes">
      <files pattern="templates/*.xml"/>
    </collection>
  </group>
  
  <!--
  Group named task: The trigger used by Tasks feature needs some XQuery modules loaded in eXist:
  -->
  <group name="tasks" incl="switch">
    <!-- oppidum -->
     <collection name="/db/www/oppidum/lib" policy="guest-can-open-collection" inherit="yes">
      <files pattern="oppidum:lib/util.xqm" type="application/xquery"/>
      <files pattern="oppidum:lib/compat.xqm" type="application/xquery"/>
    </collection>  
    <!-- excm -->
    <collection name="/db/www/excm/lib" policy="guest-can-open-collection" inherit="yes">
      <files pattern="excm:lib/globals.xqm" type="application/xquery"/>
      <files pattern="excm:lib/database.xqm" type="application/xquery"/>
      <files pattern="excm:lib/cache.xqm" type="application/xquery"/>
      <files pattern="excm:lib/user.xqm" type="application/xquery"/>      
      <files pattern="excm:lib/misc.xqm" type="application/xquery"/>
    </collection>  
    <collection name="/db/www/excm/lib" policy="guest-can-open-collection" inherit="yes">
      <!--files pattern="excm:lib/mail.xqm" type="application/xquery"/-->
      <files pattern="excm:lib/xal.xqm" type="application/xquery"/>        
    </collection>
    <!-- ccmatch --> 
    <collection name="/db/www/ccmatch/lib" policy="guest-can-open-collection" inherit="yes">
      <files pattern="lib/globals.xqm" type="application/xquery"/>
      <files pattern="lib/display.xqm" type="application/xquery"/>
    </collection>
    <collection name="/db/www/ccmatch/lib" policy="guest-can-open-collection" inherit="yes">
      <files pattern="lib/template.xqm" type="application/xquery"/>
      <files pattern="lib/util.xqm" type="application/xquery"/>
    </collection>
    <collection name="/db/www/ccmatch/modules/community" policy="guest-can-open-collection" inherit="yes">
      <files pattern="modules/community/drupal.xqm" type="application/xquery"/>
      <files pattern="modules/community/community.xqm" type="application/xquery"/>
      <files pattern="modules/community/console.xql" type="application/xquery"/>
    </collection>   
    <collection name="/db/www/ccmatch/modules/tasks" policy="guest-can-open-collection" inherit="yes">
     <files pattern="modules/tasks/tasks.xqm" type="application/xquery"/>
     <files pattern="modules/tasks/tasks-interpretor.xqm" type="application/xquery"/>
     <files pattern="modules/tasks/tasks.xql" type="application/xquery"/>
    </collection>
    <collection name="/db/tasks/ccmatch" policy="guest-can-open-collection" inherit="yes">
      <files pattern="modules/tasks/community.xml" type="text/xml"/>
    </collection>
    <collection name="/db/debug" collection-policy="unrestricted-collection" resource-policy="unrestricted-document" inherit="yes">
      <files pattern="modules/tasks/tasks.xml" type="text/xml"/>
    </collection>    
  </group> 
  
  <group name="jobs" incl="switch">
    <collection name="/db/sites/ccmatch/histories" collection-policy="unrestricted-collection" resource-policy="unrestricted-document" inherit="yes"/>
    <collection name="/db/www/ccmatch/lib" resource-policy="strict-code" inherit="resource">
      <files pattern="lib/globals.xqm"/>
      <files pattern="lib/display.xqm"/>
      <files pattern="lib/access.xqm"/>
      <files pattern="lib/ajax.xqm"/>
      <files pattern="lib/util.xqm"/>
      <files pattern="lib/form.xqm"/>
      <files pattern="lib/media.xqm"/>
      <files pattern="lib/data.xqm"/>
      <files pattern="lib/services.xqm"/>
      <files pattern="lib/histories.xqm"/>
      <files pattern="lib/nonce.xqm"/>
    </collection>
    <collection name="/db/www/ccmatch/modules/alerts" resource-policy="strict-code" inherit="resource">
      <files pattern="modules/alerts/check.xqm"/>
      <files pattern="modules/alerts/job.xql"/>
    </collection>
    <collection name="/db/www/ccmatch/modules/feeds" resource-policy="strict-code" inherit="resource">
      <files pattern="modules/feeds/feeds.xqm"/>
      <files pattern="modules/feeds/job.xql"/>
    </collection>
    <collection name="/db/www/ccmatch/modules/users" resource-policy="strict-code" inherit="resource">
      <files pattern="modules/users/account.xqm"/>
    </collection>
    <collection name="/db/www/ccmatch/modules/suggest" resource-policy="strict-code" inherit="resource">
      <files pattern="modules/suggest/match.xqm"/>
    </collection>
    <!-- oppidum -->
    <collection name="/db/www/oppidum/lib" resource-policy="strict-code" inherit="resource">
      <files pattern="oppidum:lib/util.xqm" type="application/xquery"/>
      <files pattern="oppidum:lib/compat.xqm" type="application/xquery"/>
    </collection>
  </group>
  </code>;

(:  <!-- ***************
       ** on demand **
       *************** -->:)

(: ======================================================================
   FIXME: to be factorized somewhere in all first level modules
   ====================================================================== 
:)
  declare function local:do-post-deploy-actions ( $dir as xs:string,  $targets as xs:string*, $base-url as xs:string, $mode as xs:string ) {
  (: terminates globals.xml installation usually once after bootstrap.sh - no -uri convention ! :)
  if ('globals' = $targets) then (
    <p>globals post-treatment :</p>,
    <ul>
      {
      for $global in fn:doc($globals:globals-uri)//Global[not(Value)]
      let $value := if (exists($global/Eval)) then string($global/Eval) else concat('$globals:', $global/Key, '-uri')
      return (
        update insert <Value>{ util:eval($value) }</Value> into $global,
        if (exists($global/Eval)) then
          update delete $global/Eval
        else
          (),
        <li>replacing { $value } into globals</li>
        )
      }
    </ul>
    )
  else
    (),
  if ('config' = $targets) then
    let $mapping := fn:doc('/db/www/ccmatch/config/mapping.xml')/site
    let $settings := fn:doc('/db/www/ccmatch/config/settings.xml')/Settings
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
        <p>SMTP Server is configured to "{string($settings/SMTPServer)}"</p>,
      <p>Do not forget to run platform deploy command if necessary !</p>
      )
  else
    ()
};

declare function local:deploy ( $dir as xs:string,  $targets as xs:string*, $base-url as xs:string, $mode as xs:string ) {
  (
  let $itargets := $targets[not(. = ('forms', 'cross-search', 'tasks'))]
  return
    if (count($itargets) > 0) then
      <target name="{string-join($itargets,', ')}">
        {  
        install:install-targets($dir, $itargets, $code, ())
      }
      </target>
    else
      (),
  if (('forms', 'cross-search') = $targets) then
    <target name="forms" base-url="{$base-url}">{ sg:gen-and-save-forms($formulars, $base-url) }</target>
  else
    (),
  if ('tasks' = $targets) then
    <target name="tasks" base-url="{$base-url}">{ (install:install-targets($dir, 'tasks', $code, ()),
                                                   install:install-policies(('tasks'), $policies, $code, ()))}</target>
  else
    (),
  if ('policies' = $targets) then
    <target name="policies">
      {
      for $c in $code/install:group[empty(@optional) or @optional eq 'no']/install:collection[(@collection-policy or @resource-policy)]
      return
        install:install-policy($c, $policies)
      }
    </target>
  else if ($targets = $code/install:group[@optional and @optional eq 'yes']/@name) then
    (: finish configuration of optional targets :)
    for $c in $code/install:group[@optional and @optional eq 'yes']/install:collection[(@collection-policy or @resource-policy)]
    return
      install:install-policy($c, $policies)
  else
    (),
  (: must be done after other targets that could create colletions/resources :)
  if (('reindex') = $targets) then (
    <p>reindexing /db/sites/ccmatch collections { xdb:reindex('/db/sites/ccmatch') }</p>,
    <p>reindexing /db/www/ccmatch collections { xdb:reindex('/db/www/ccmatch') }</p>
    )
  else
    (),
  local:do-post-deploy-actions($dir, $targets, $base-url, $mode)
  )
};

(: *** MAIN ENTRY POINT ***:)
let $dir := install:webapp-home(concat($globals:app-folder, '/', $globals:app-name))
let $pwd := request:get-parameter('pwd', ())
let $mode := request:get-parameter('m', fn:doc(concat('/db/www/', $globals:app-name, '/config/mapping.xml'))/site/@mode)
let $targets := tokenize(request:get-parameter('t', ''), ',')
let $host := request:get-header('Host')
let $cmd := request:get-attribute('oppidum.command')
return
  if (starts-with($host, 'localhost') or starts-with($host, '127.0.0.1')) then
    if ($pwd and not($targets = 'help') and deploy:targets-available($targets, $code)) then
      try {
        if ($targets = distinct-values($code/install:group/@incl)) then
          if (count($targets) eq 1) then
            <results count="{count($targets)}">
              <dir>{$dir}</dir>
              { system:as-user('admin', $pwd, deploy:deploy-targets($code, $policies, $targets, $dir, $cmd/@base-url, $mode, function-lookup(xs:QName("local:deploy"), 4))) }
            </results>
          else
            <results>{ $targets } target cannot be combined with others</results>
        else
          <results count="{count($targets)}">
            <dir>{$dir}</dir>
            { system:as-user('admin', $pwd, local:deploy($dir, $targets, $cmd/@base-url, $mode)) }
          </results>
      } catch * {
        <error>Caught error {$err:code}</error>
      }
    else
      <results>Usage : deploy?t={ deploy:gen-targets($code) }&amp;pwd=[ADMIN PASSWORD]&amp;m=(dev | test | [prod])</results>
  else
    <results>This script can be called only from the server</results>
