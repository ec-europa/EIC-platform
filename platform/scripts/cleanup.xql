xquery version "1.0";
(: --------------------------------------
   SMEIMKT

   Creator: Stéphane Sire <sire@oppidoc.fr>

   Utility to archive /db/debug/debug.xml to file system and reset it

   Use : curl "http://localhost:PORT/exist/projets/platform/cleanup?params"
         with params in "pwd=PASSWORD&t=[debug|login|histories][&d=/path/to/dir]"

   Run this script from each SMEIMKT module

   Pre-requisite:

     if you do not specify a backup directory (d parameter), 
     eXist-DB must be installed in lib directory and you must 
     create an EXIST_HOME/../debug directory

   November 2016 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

declare variable $local:help := 
  <results>
    <help>Cleanup log files in /db/debug collection and in /db/sites/[{string-join(local:get-module-names(), ', ')}]/histories collection</help>
    <newline/>
    <help>Parameters</help>
    <help># pwd=PASSWORD admin password</help>
    <help># t=login to cleanup login.xml</help>
    <help># t=debug to cleanup debug.xml</help>
    <help># t=histories to cleanup histories</help>
    <help># d=/path/to/dir optional backup destination directory (defaults to EXIST-HOME/../debug)</help>
    <newline/>
    <help>eXist-DB MUST be installed in a directory called lib if you do not specify the d parameter</help>
    <newline/>
  </results>;

(: ======================================================================
   Returns the list of deployed modules with histories collection
   ====================================================================== 
:)
declare function local:get-module-names() as xs:string* {
  for $c in xdb:get-child-collections('/db/sites')
  where xdb:collection-available(concat('/db/sites/', $c, '/histories'))
  return $c
};

(: ======================================================================
   Returns legacy content to persists when resetting resource
   ====================================================================== 
:)
declare function local:reset-content( $target as xs:string, $root as element()? ) as item()* {
  let $today := substring(string(current-date()), 1, 10)
  let $yesterday := substring(string(current-date() - xs:dayTimeDuration("P1D")), 1, 10)
  return
    if ($target eq 'login') then (
      $root/@*[local-name(.) ne 'LastCleanup'],
      (: preserves last 2 days :)
      $root/Login[starts-with(@TS, $today) or starts-with(@TS, $yesterday)]
      )
    else
      ()
};

declare function local:cleanup( $target as xs:string, $filename as xs:string, $filepath as xs:string ) as element() {
  let $fileuri := concat($filepath, '/', $filename)
  return
    if (not(file:exists($fileuri))) then
      if (file:exists($filepath)) then
        let $root := fn:doc(concat('/db/debug/', $target, '.xml'))/*
        return
          if (file:serialize($root, $fileuri, ())) then (
            <results>
              {
              if ($root/@LastCleanup) then
                <cleanup>last cleanup {string($root/@LastCleanup)}</cleanup>
              else
                ()
              }
              <cleanup>archive file created at {$fileuri}</cleanup>
              <cleanup>resource reset of { 
                xdb:store('/db/debug', concat($target, '.xml'), 
                  element { local-name($root) } { 
                    attribute { 'LastCleanup' } { current-dateTime() },
                    local:reset-content($target, $root)
                  }
                ) 
                }
              </cleanup>
              <newline/>
            </results>
            )
          else
            <error>failed to write archive file { $fileuri }</error>
      else
        <error>directory {$filepath} does not exists</error>
    else
      <error>archive file {$fileuri} already exists</error>
};

(: ======================================================================
   Archives /db/sites/{$name}/histories
   Histories granularity is one resource per month
   Only archives past-months, not month in progress
   ====================================================================== 
:)
declare function local:cleanup-histories( $module as xs:string, $filepath as xs:string ) as element()* {
  let $cur-month := substring(string(current-date()), 1,7)
  let $parent := concat('/db/sites/', $module, '/histories')
  return
    if (exists(xdb:get-child-resources($parent)[not(starts-with(., $cur-month)) and matches(., "^\d\d\d\d-\d\d")])) then
      for $cur in xdb:get-child-resources($parent)
      let $filename := concat($module, '-histories-', substring(string($cur), 1, 7), '.xml')
      let $fileuri := concat($filepath, '/', $filename)
      let $root := fn:doc(concat('/db/sites/', $module, '/histories/', $cur))/*
      where not(starts-with($cur, $cur-month)) and matches($cur, "^\d\d\d\d-\d\d")
      order by $cur
      return
        if (not(file:exists($fileuri))) then
          if (file:serialize($root, $fileuri, ())) then
            <cleanup>archive for { $filename } created at { $filepath }, resource { xdb:remove($parent, $cur), $cur } deleted</cleanup>
          else
            <error>failed to write archive file { $fileuri }</error>
        else
          <error>archive file {$fileuri} already exists</error>
    else
      <cleanup>nothing to archive in { $parent }</cleanup>
};

declare function local:run( $target as xs:string?, $filepath as xs:string ) as element() {
  let $date := substring(string(current-date()), 1, 10)
  return
    if (file:exists($filepath)) then
      if ($target = ('debug', 'login')) then
        let $filename := concat($target, '-', $date, '.xml')
        return
          local:cleanup($target, $filename, $filepath)
      else if ($target = ('histories')) then
        let $modules := local:get-module-names()
        return
          if (exists($modules)) then
            <results>
              {
              for $name in $modules
              return local:cleanup-histories($name, $filepath)
              }
            </results>
          else
            <error>no histories collection to archive</error>
      else
        $local:help
    else
      <results>
        { $local:help/* }
        <error>directory {$filepath} does not exists</error>
      </results>
};

(: WARNING: works only if eXist-DB installed in lib directory ! :)
let $default := concat(substring-before(system:get-exist-home(), '/lib'), '/debug')
let $filepath := request:get-parameter('d', $default)
let $pwd := request:get-parameter('pwd', ())
let $target := request:get-parameter('t', ())
return
  if ($pwd) then
    system:as-user('admin', $pwd, local:run($target, $filepath))
  else
    $local:help

