xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Utility to deploy the application after a code update on file system with git

   You can use it for initial deployment or for maintenance updates,
   do not forget to separately restore the application data and/or system collection (users accounts)

   PRE-CONDITIONS :
   - scripts/bootstrap.sh has been executed first (to install mapping.xml inside database)
   - must be called from the server (e.g.: using curl or wget)
   - admin password must be provided as a pwd parameter

   SYNOPSIS :
   curl -i http:127.0.0.1:[PORT]/exist/projects/cockpit/admin/deploy?pwd=[PASSWORD]&t=[TARGETS]
   (or wget -O-)

   TARGETS
   - all : everything (except user data, except indexes)
           install settings.xml, services.xml and security.xml only the first time
           (these should be deployed through platform depot anyway)
   - switch : most application configuration, should be sufficient when switching between branches
   - indexes : install indexes in /Db/system/config and reindex collections
   - reindex : reindex collections

   POST-INSTALLATION :
   - for EU Login access check user '_ecas_' exists or create it manually (see security.xml)

   March 2017 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";
import module namespace install = "http://oppidoc.com/oppidum/install" at "../../oppidum/lib/install.xqm";
import module namespace deploy = "http://oppidoc.com/ns/deploy" at "../../excm/lib/deploy.xqm";
import module namespace sg = "http://oppidoc.com/ns/xcm/supergrid" at "../../xcm/modules/formulars/install.xqm";

declare option exist:serialize "method=xml media-type=text/html indent=yes";

declare variable $formulars :=
  let $reg := fn:doc(concat('file://', system:get-exist-home(), '/webapp/projects/', $globals:app-name, '/formulars/_register.xml'))
  return string-join(for $i in $reg//Form return substring-after($i, 'forms/'), '+');

declare variable $policies := <policies xmlns="http://oppidoc.com/oppidum/install">
  <!-- Policies -->
  <policy name="dba" owner="SYSTEM" group="dba" perms="rw-r--r--"/>
  <policy name="admin" owner="admin" group="users" perms="rwxr-x---"/>
  <policy name="any-up" owner="admin" group="users" perms="rwxr-x---"/>
  <policy name="users" owner="admin" group="users" perms="rwxrwxr--"/>
  <policy name="open" owner="admin" group="users" perms="rwxrwxrwx"/>
  <policy name="strict" owner="admin" group="users" perms="rwxrwx---"/>
  <policy name="guest" owner="admin" group="users" perms="rwxr-xr-x"/>
</policies>;

declare variable $code := <code xmlns="http://oppidoc.com/oppidum/install">
  <targets>
    <set name="bootstrap"><incl>restore</incl><incl>switch</incl><target>policies</target></set>
    <set name="restore"><incl>switch</incl><target>policies</target></set>
    <set name="*"><incl>forms</incl></set>
    <target name="forms"/>
    <target name="policies"/>
    <target name="reindex"/>
  </targets>
  <collection name="/db/www/{$globals:app-collection}" collection-policy="guest" resource-policy="dba" inherit="yes"/>
  <collection name="/db/sites/{$globals:app-collection}" collection-policy="users" resource-policy="users" inherit="yes"/>
  <collection name="/db/binaries/{$globals:app-collection}" collection-policy="users" resource-policy="users" inherit="yes"/>
  <group name="batch" incl="bootstrap">
    <collection name="/db/batch" policy="admin"/>
  </group>
  <group name="globals" incl="bootstrap">
    <collection name="/db/www/xcm/config">
      <files pattern="config/globals.xml"/>
    </collection>
  </group>
  <group name="caches" incl="restore">
    <collection name="/db/caches/{$globals:app-collection}" collection-policy="users" resource-policy="users" inherit="yes">
      <files pattern="data/caches/cache.xml"/>
    </collection>
  </group>
  <group name="debug" incl="bootstrap">
    <collection name="/db/debug" collection-policy="open" resource-policy="open" inherit="yes">
      <!--<files pattern="data/debug/xal.xml"/>-->
      <files pattern="excm:data/debug/debug.xml"/>
      <files pattern="data/debug/services.xml"/>
      <files pattern="excm:data/debug/login.xml"/>
    </collection>
  </group>
  <group name="config" incl="switch">
    <collection name="/db/www/{$globals:app-collection}/config">
      <files pattern="config/mapping.xml"/>
      <files pattern="config/modules.xml"/>
      <files pattern="config/application.xml"/>
      <files pattern="config/database.xml"/>
      <files pattern="config/skin.xml"/>
      <files pattern="config/errors.xml"/>
      <files pattern="config/messages.xml"/>
      <files pattern="config/dictionary.xml"/>
      <files pattern="config/variables.xml"/>
    </collection>
  </group>
  <group name="mesh" incl="switch">
    <collection name="/db/www/{$globals:app-collection}/mesh">
      <files pattern="mesh/*.html"/>
    </collection>
  </group>
  <group name="data" incl="switch">
    <collection name="/db/sites/{$globals:app-collection}/global-information">
      <files pattern="data/global-information/*.xml"/>
    </collection>
  </group>
  <group name="templates" incl="switch">
    <collection name="/db/www/{$globals:app-collection}/templates">
      <files pattern="templates/*.xml"/>
    </collection>
  </group>
  <group name="bootstrap" incl="bootstrap">
    <collection name="/db/sites/{$globals:app-collection}/persons/0000">
      <files pattern="data/persons/*.xml"/>
    </collection>
    <collection name="/db/sites/{$globals:app-collection}/enterprises/0000">
      <files pattern="data/enterprises/*.xml"/>
    </collection>
    <collection name="/db/sites/{$globals:app-collection}/events/0000">
      <files pattern="data/events/*.xml"/>
    </collection>
  </group>
  <group name="indexes" incl="bootstrap">
    <collection name="/db/system/config/db/sites/{$globals:app-collection}/enterprises">
      <files pattern="indexes/enterprises/collection.xconf" type="text/xml"/>
    </collection>
    <collection name="/db/system/config/db/sites/{$globals:app-collection}/persons">
      <files pattern="indexes/persons/collection.xconf" type="text/xml"/>
    </collection>
    <collection name="/db/system/config/db/sites/{$globals:app-collection}/global-information">
      <files pattern="indexes/global-information/collection.xconf" type="text/xml"/>
    </collection>
    <collection name="/db/system/config/db/www"/>
  </group>
  <!--
    Group named task: The trigger used by Tasks feature needs some XQuery modules loaded in eXist:
    -->
    <group name="tasks" incl="switch">
      <!-- oppidum -->
       <collection name="/db/www/oppidum/lib" policy="guest" inherit="yes">
        <files pattern="oppidum:lib/util.xqm" type="application/xquery"/>
        <files pattern="oppidum:lib/compat.xqm" type="application/xquery"/>
      </collection>  
      <!-- xcm -->
      <collection name="/db/www/xcm/lib" policy="guest" inherit="yes">
        <files pattern="xcm:lib/globals.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/database.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/cache.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/user.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/display.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/form.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/access.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/ajax.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/services.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/util.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/check.xqm" type="application/xquery"/>   
        <files pattern="xcm:lib/media.xqm" type="application/xquery"/>
      </collection>  
      <collection name="/db/www/xcm/modules/users" policy="guest" inherit="yes">
        <files pattern="xcm:modules/users/account.xqm" type="application/xquery"/>
      </collection>
      <collection name="/db/www/xcm/modules/enterprises" policy="guest" inherit="yes">
        <files pattern="xcm:modules/enterprises/enterprise.xqm" type="application/xquery"/>
      </collection>
      <collection name="/db/www/xcm/lib" policy="guest" inherit="yes">
        <files pattern="xcm:lib/mail.xqm" type="application/xquery"/>
        <files pattern="xcm:lib/xal.xqm" type="application/xquery"/>        
      </collection>
      <collection name="/db/www/xcm/modules/workflow" policy="guest" inherit="yes">
        <files pattern="xcm:modules/workflow/workflow.xqm" type="application/xquery"/>
        <files pattern="xcm:modules/workflow/alert.xqm" type="application/xquery"/>        
      </collection>
      <!-- Cockpit --> 
      <collection name="/db/www/cockpit/lib" policy="guest" inherit="yes">
        <files pattern="lib/globals.xqm" type="application/xquery"/>
        <files pattern="lib/display.xqm" type="application/xquery"/>
      </collection>
      <collection name="/db/www/cockpit/app" policy="guest" inherit="yes">
        <files pattern="app/custom.xqm" type="application/xquery"/>
      </collection>
      <collection name="/db/www/cockpit/lib" policy="guest" inherit="yes">
        <files pattern="lib/template.xqm" type="application/xquery"/>
        <files pattern="lib/util.xqm" type="application/xquery"/>
      </collection>
      <collection name="/db/www/cockpit/modules/enterprises" policy="guest" inherit="yes">
        <files pattern="modules/enterprises/enterprise.xqm" type="application/xquery"/>
      </collection>
      <collection name="/db/www/cockpit/modules/community" policy="guest" inherit="yes">
        <files pattern="modules/community/drupal.xqm" type="application/xquery"/>
        <files pattern="modules/community/community.xqm" type="application/xquery"/>
        <files pattern="modules/community/console.xql" type="application/xquery"/>
      </collection>     
      <collection name="/db/www/cockpit/modules/tasks" policy="guest" inherit="yes">
       <files pattern="modules/tasks/tasks.xqm" type="application/xquery"/>
       <!--files pattern="modules/tasks/tasks-trigger.xqm" type="application/xquery"/-->
       <files pattern="modules/tasks/tasks-interpretor.xqm" type="application/xquery"/>
       <files pattern="modules/tasks/tasks.xql" type="application/xquery"/>
      </collection>
      <!--collection name="/db/system/config/db/tasks/cockpit" policy="dba" inherit="yes">
        <files pattern="modules/tasks/collection.xconf" type="text/xml"/>
      </collection-->
      <collection name="/db/tasks/cockpit" policy="users" inherit="yes">
        <files pattern="modules/tasks/community.xml" type="text/xml"/>
      </collection>
    </group> 
</code>;

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
  (: terminates globals.xml installation usually once after bootstrap.sh :)
  if ('globals' = $targets) then
    for $global in fn:doc($globals:globals-uri)//Global[not(Value)]
    let $value := if (exists($global/Eval)) then string($global/Eval) else concat('$globals:', $global/Key)
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
    let $mapping := fn:doc(concat('/db/www/', $globals:app-collection, '/config/mapping.xml'))/site
    let $settings := fn:doc(concat('/db/www/', $globals:app-collection, '/config/settings.xml'))/Settings
    return
      (
      update value $mapping/@mode with $mode,
      <p>Set mode to { $mode }</p>,
      <p>Root mapping supported actions set to { string($mapping/@supported) }</p>,
      if  (not(exists($mapping/@base-url)) and $mode = ('test', 'prod')) then
        (
        update insert attribute { 'base-url' } {'/'} into $mapping,
        <p>Set attribue base-url to '/'</p>
        )
      else (
        if (exists($mapping/@base-url)) then (
          update delete $mapping/@base-url,
          <p>Removed attribute base-url for '{ $mode }'</p>
          )
        else
          <p>No need to removed attribute base-url for '{ $mode }'</p>
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
    (),
  if (('indexes', 'reindex') = $targets) then
    for $c in $code/install:group[@name eq "indexes"]/install:collection
    let $col-uri := replace($c/@name, '/db/system/config', '')
    return (
      <p>Reindexing collections { $col-uri }</p>,
      xdb:reindex($col-uri)
      )
  else
    ()
};

declare function local:deploy ( $dir as xs:string,  $targets as xs:string*, $base-url as xs:string, $mode as xs:string ) {
  (
  if ('users' = $targets) then (: DEPRECATED TARGET TO BE REMOVED :)
    <target name="users">
      { 
      (: TODO: add function compat:make-user-groups and use it in install-users :)
      (: the code below creates the groups first so it can use deprecated xdb:create/change-user :)
      let $groups := sm:list-groups()
      return 
        (: pre-condition: target config already deployed :)
        for $group in ('users', fn:doc(concat('file://', system:get-exist-home(), '/webapp/projects/', $globals:app-name, '/data/global-information/global-information.xml'))//Description[@Role eq 'normative']/Selector[@Name eq 'Functions']/Option[@Group]/string(@Group))
        return
          if ($group = $groups) then
            <li>no need to create group {$group} which already exists</li>
          else
            <li>Created group { sm:create-group($group), $group }</li>,
      install:install-users($policies)
      }
    </target>
  else
    (),
  let $itargets := $targets[not(. = ('users', 'policies', 'forms', 'tasks'))]
  return
    if (count($itargets) > 0) then
      <target name="{string-join($itargets,', ')}">
        {  
        install:install-targets($dir, $itargets, $code, ())
      }
      </target>
    else
      (),
  if ('policies' = $targets) then
   (: install policies on $code direct collection child and on collection with policy configuration inside list of target groups  :)
    <target name="policies">{ install:install-policies(('debug', 'caches'), $policies, $code, ())}</target>
  else
    (),
  if ('debug' = $targets) then
    <target name="policies">{ install:install-policies(('debug'), $policies, $code, ())}</target>
  else
    (),    
  if ('forms' = $targets) then
    <target name="forms" base-url="{$base-url}">{ sg:gen-and-save-forms($formulars, $base-url, $globals:app-name) }</target>
  else
    (),   
  if ('tasks' = $targets) then
    <target name="tasks" base-url="{$base-url}">{ (install:install-targets($dir, 'tasks', $code, ()),
                                                   install:install-policies(('tasks'), $policies, $code, ()))}</target>
  else
    (),
  (:if ('services' = $targets) then
    (<target name="services">{ services:deploy($dir) }</target>,
	install:install-targets($dir, ('questionnaires'), $code, ()))
  else
    (),:)
  local:do-post-deploy-actions($dir, $targets, $base-url, $mode)
  )
};

(: ======================================================================
   Display a reminder to deploy platform target 
   ====================================================================== 
:)
declare function local:gen-post-action-helper( $mode as xs:string ) {
  let $cmd := oppidum:get-command()
  return
    <p>Post-action : http://localhost:{request:get-server-port()}{replace($cmd/@base-url, $globals:app-name, 'platform')}deploy?m={ $mode }&amp;pwd=PASSWORD</p>
};

let $dir := install:webapp-home(concat('projects/', $globals:app-name))
let $pwd := request:get-parameter('pwd', ())
let $mode := request:get-parameter('m', fn:doc(concat('/db/www/', $globals:app-collection, '/config/mapping.xml'))/site/@mode)
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
      <results>
        <p>Usage : deploy?t={ deploy:gen-targets($code) }&amp;pwd=[ADMIN PASSWORD]&amp;m=(dev | test | [prod])</p>
        { local:gen-post-action-helper($mode) }
      </results>
  else
    <results>This script can be called only from the server (localhost or 127.0.0.1)</results>
