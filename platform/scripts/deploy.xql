xquery version "1.0";
(: --------------------------------------
   SMEIMKT

   Creator: Stéphane Sire <sire@oppidoc.fr>

   Utility to deploy environment dependent configuration data in SMEIMKT modules

   You can use it post-deployment to install the environment dependent configuration
   files into each SMEIMKT module.

   For that purpose :
   - checkout this smeimkt depot into the project folder of each SMEIMKT module
   - bootstrap it the first time you want to install it with ./scripts/bootstrap.sh
   - for each module using port XXXX, run it with :
     curl "http://127.0.0.1:XXXX/exist/projets/smeimkt/deploy&pwd=PASSWORD?m=prod|test"

   Use :
   - run this script for each SMEIMKT module !!!

   September 2016 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace install = "http://oppidoc.com/oppidum/install" at "../../oppidum/lib/install.xqm";

declare option exist:serialize "method=xml media-type=application/xml indent=yes";

declare variable $policies := <policies xmlns="http://oppidoc.com/oppidum/install">
  <!-- Policies : MUST be synchronized between all modules
       FIXME : move to smeimkt/config/policies.xml (?)
    -->
  <policy name="admin" owner="admin" group="users" perms="rwur--r--"/>
  <policy name="any-up" owner="admin" group="users" perms="rwur-ur-u"/>
  <policy name="users" owner="admin" group="users" perms="rwurwur--"/>
  <policy name="open" owner="admin" group="users" perms="rwurwurwu"/>
  <policy name="strict" owner="admin" group="users" perms="rwurwu---"/>
</policies>;

(: ======================================================================
   FIXME: could be stored in database ?
   ======================================================================
:)
declare variable $smeimkt-code :=
  <platform>
    <module name="cctracker" mode="dev test prod">
      <code xmlns="http://oppidoc.com/oppidum/install">
        <group name="config">
          <collection name="/db/www/cctracker/config">
            <files pattern="config/services.xml"/>
            <files pattern="config/settings.xml"/>
          </collection>
        </group>
      </code>
    </module>
    <module name="ccmatch" mode="dev test prod">
      <code xmlns="http://oppidoc.com/oppidum/install">
        <group name="config">
          <collection name="/db/www/ccmatch/config">
            <files pattern="config/settings.xml"/>
            <files pattern="config/services.xml"/>
          </collection>
        </group>
      </code>
    </module>
    <module name="poll" mode="dev test prod">
      <code xmlns="http://oppidoc.com/oppidum/install">
        <group name="config">
          <collection name="/db/www/poll/config">
            <files pattern="config/settings.xml"/>
            <files pattern="config/services.xml"/>
          </collection>
        </group>
      </code>
    </module>
  </platform>;

(: ======================================================================
   TODO: ?
   ======================================================================
:)
declare function local:do-post-casetracker-actions ( $mode as xs:string ) {
  local:reset-sudoer('cctracker'),
  local:reset-surrogates('cctracker')
};

(: ======================================================================
   TODO: ?
   ======================================================================
:)
declare function local:do-post-ccmatch-actions ( $mode as xs:string ) {
  local:reset-sudoer('ccmatch'),
  local:reset-surrogates('ccmatch')
};

(: ======================================================================
   Synch poll agent user as per settings.xml
   ======================================================================
:)
declare function local:do-post-poll-actions ( $mode as xs:string ) {
  local:reset-sudoer('poll'),
  (: reminder :)
  if (xdb:exists-user('poll')) then
    <p>user "poll" exists, you can access /admin</p>
  else
    <p>user "poll" missing, create it if you want to access /admin</p>
};

(: ======================================================================
   Function to generate a random password
   ======================================================================
:)
declare function local:gen-password ( $name as xs:string, $seed as xs:string ) {
  let $boot := concat($name, current-dateTime(), $seed)
  let $next := util:hash($boot,"md5")
  let $seed :=
        string-join(
    for $i in 1 to string-length($next)
    return
        if (($i mod 2 = 0) or ($i mod 3 = 0) or ($i mod 5 = 0)) then
          translate(substring($next, $i, 1),"012345", "aeiouy")
        else
          substring($next, $i, 1),
        ''
        )
  let $max := string-length($seed)
  return
    string-join(
      for $i in 1 to 8
      return
           let $pos := util:random($max)
           let $res := substring($seed, $pos, 1)
           return
               if ($pos > $max div 2) then
                    upper-case($res)
               else
                    $res,
      '')
};

(: ======================================================================
   Generates a random password and updates or create user
   Creates with groups membership, does not change groups if user already exists
   Returns sequence (feedback message, new generated password)
   ======================================================================
:)
declare function local:reset-user( $module as xs:string, $user as xs:string, $pwd as xs:string?, $groups as xs:string* ) as item()* {
  let $pwd := local:gen-password($user, $pwd)
  return (
    if (xdb:exists-user($user)) then (
      xdb:change-user($user, $pwd, (), ()),
      <p>{ $module} "{ $user }" password updated with password "{ $pwd }" no change to groups : { xdb:get-user-groups($user) }</p>
      )
    else (
      xdb:create-user($user, $pwd, $groups, ()),
      <p>{ $module} "{ $user }" created with password "{ $pwd }" and groups : { string-join($groups, ', ') }</p>
      ),
    $pwd
    )
};

(: ======================================================================
   Generates a random password and updates or create Sudoer secret user
   ======================================================================
:)
declare function local:reset-sudoer( $module as xs:string ) {
  let $agent := fn:doc(concat('/db/www/', $module, '/config/settings.xml'))/Settings/Sudoer
  let $done := local:reset-user($module, $agent/User, $agent/Password, 'dba')
  let $pwd := $done[2]
  return (
    $done[1],
    if (exists($agent/Password)) then
      update value $agent/Password with $pwd
    else
      update insert <Password>{ $pwd }</Password> into $agent
    )
};

(: ======================================================================
   Generates a random password and updates or create Surrogate users 
   Pre-condition: security.xml copied to application configuration
   ======================================================================
:)
declare function local:reset-surrogates( $module as xs:string ) {
  let $agents := fn:doc(concat('/db/www/', $module, '/config/security.xml'))//Surrogate
  return
    for $user in distinct-values($agents/User)
    return
      let $done := local:reset-user($module, $user, ($agents/Password)[1], distinct-values($agents//Group))
      let $pwd := $done[2]
      return (
        $done[1],
        for $agent in $agents[User eq $user]
        return
          if (exists($agent/Password)) then
            update value $agent/Password with $pwd
          else
            update insert <Password>{ $pwd }</Password> into $agent
        )
};

(: ======================================================================
   Switch mode for module in mapping including base URL
   ====================================================================== 
:)
declare function local:switch-mode ( $module as xs:string, $mode as xs:string ) {
  let $mapping := fn:doc(concat('/db/www/', $module, '/config/mapping.xml'))/site
  return (
    if ($mapping/@mode ne $mode) then (
      update value $mapping/@mode with $mode,
      <p>change mode to { $mode }</p>
      )
    else
      <p>keep mode { $mode }</p>,
    if ($mode eq 'dev') then
      if (exists($mapping/@base-url)) then (
        update delete $mapping/@base-url,
        <p>remove attribue base-url</p>
        )
      else
        ()
    else
      if (not(exists($mapping/@base-url))) then 
        (
        update insert attribute { 'base-url' } { '/' } into $mapping,
        <p>set base-url to "/"</p>
        )
      else
        <p>keep base-url "{ string($mapping/@base-url) }" </p>
    )
};

(: ======================================================================
   Deploys environmental configuration
   ======================================================================
:)
declare function local:deploy (
  $module as xs:string,
  $dir as xs:string,
  $targets as xs:string*,
  $base-url as xs:string,
  $mode as xs:string,
  $rules as element()
  )
{
  if (count($targets) > 0) then
    <target name="{string-join($targets,', ')}">
      {
      install:install-targets($dir, $targets, $rules, ())
      }
    </target>
  else
    (),
  if ('config' = $targets) then (: "rwur-u-r--" :)
    xdb:set-resource-permissions(concat('/db/www/', $module, '/config'), 'settings.xml', 'admin', 'admin-system', 492)
  else
    (),
  <post>
    {
    local:switch-mode($module, $mode),
    if ($module eq 'cctracker') then
      local:do-post-casetracker-actions ($mode)
    else if ($module eq 'ccmatch') then
      local:do-post-ccmatch-actions ($mode)
    else if ($module eq 'poll') then
      local:do-post-poll-actions ($mode)
    else
      ()
    }
  </post>
};

(: ======================================================================
   Deployment target actually limited to the config group
   and to per-module post-deployment scripts
   ======================================================================
:)
let $module := fn:collection('/db/www')//site[not(@key = ('oppidum', 'platform', 'oppistore'))]/string(@key)
let $pwd := request:get-parameter('pwd', ())
let $mode := request:get-parameter('m', string(fn:doc(concat('/db/www/', $module[1], '/config/mapping.xml'))/site/@mode))
let $targets := 'config'
let $host := request:get-header('Host')
let $cmd := request:get-attribute('oppidum.command')
return
    if (count($module) eq 1) then
      if (starts-with($host, 'localhost') or starts-with($host, '127.0.0.1')) then
        if ($pwd and ($mode = ('dev', 'test', 'prod'))) then
          let $dir := install:webapp-home(concat("projets/platform/env/", $mode, '/', $module))
          let $rules := $smeimkt-code//module[@name eq $module][tokenize(@mode, ' ') = $mode]/*[local-name(.) eq 'code']
          return
            if ($rules) then
              <results count="{count($targets)}">
                <mode>{ $mode }</mode>
                <module>{ $module }</module>
                <base>{ $dir }</base>
                { system:as-user('admin', $pwd, local:deploy($module, $dir, $targets, $cmd/@base-url, $mode, $rules)) }
              </results>
            else
              <error>No installation rules found for module "{ $module }" with mode "{ $mode }"</error>
        else
          <error>Usage : "deploy?pwd=[ADMIN PASSWORD]&amp;m=(dev | test | prod)"</error>
      else
        <error>This script can be called only from the server</error>
    else
      <error>Too many or too few modules found : "{ string-join($module, ', ') }"</error>

