xquery version "3.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Authors: Frédéric Dumonceaux <Frederic.DUMONCEAUX@ext.ec.europa.eu>
            Stéphane Sire <s.sire@opppidoc.fr>

   Implementation of the report language

   Note: custom error reporting to be callable from a scheduled job
   without request / response / session objects

   Pre-conditions : collection '/db/sites/cctracker/reports' available

   See also : codegen.xql (for sample.xqm generated part of the algorithm)

   May 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace report = "http://oppidoc.com/ns/cctracker/reports";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace util = "http://exist-db.org/xquery/util";

declare namespace ms = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../../oppidum/lib/compat.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "../workflow/alert.xqm";
import module namespace excel = "http://oppidoc.com/oppidum/excel" at "../../lib/excel.xqm";
import module namespace sample = 'http://oppidoc.com/ns/cctracker/sample' at "../../gen/sample.xqm";
import module namespace miscellaneous = "http://oppidoc.com/ns/miscellaneous" at "../../../excm/lib/misc.xqm";

declare variable $report:ts := current-dateTime();
declare variable $report:freshness := xs:dayTimeDuration(miscellaneous:get-property('reports', 'freshness', 'PT86400S'));
declare variable $report:fs-regexp-escape := ('|', '$', '\'); (: non exhaustive list of field separators that need to be escaped in regexp :)

(: ======================================================================
   Add an error element to the report error log container
   ====================================================================== 
:)
declare function report:log-error( $report-no as xs:string, $error as xs:string ) {
  let $meta := fn:doc(concat($globals:reports-uri, '/', 'meta.xml'))/Meta
  return
    update insert <Error>{ $error }</Error> into $meta/Errors[@ReportRef eq $report-no]
};

(: ======================================================================
   Check cached entry freshness. Return true() if entry has expired.
   To be called from sample.xqm
   ====================================================================== 
:)
declare function report:expired( $cached as element()? ) as xs:boolean {
  if ($cached) then
    empty($cached/@Seal) and ($report:ts - xs:dateTime($cached/@TS)) > $report:freshness
  else
    true()
};

(: ======================================================================
   Construct a sample using provided $func then replace previous dirty one
   or insert sample into the report
   To be called from sample.xqm
   ====================================================================== 
:)
declare function report:make-sample( $dirty-one as element()?, $func, $cached as element()?, $valkey as xs:string, $index-pivot as xs:string, $subject as element(), $object as element(), $pivot as element()? ) as element()* {
  let $to-store := local:gen-sample-from-extract($func, $valkey, $index-pivot, $subject, $object, $pivot)
  return (
    if (exists($dirty-one)) then (
      update replace $dirty-one with $to-store,
      <Replace>replace</Replace>
      )
    else (
      update insert $to-store into $cached,
      <Insert>insert</Insert>
      )
    )
};

(: ======================================================================
   Delete a sample
   To be called from sample.xqm
   ====================================================================== 
:)
declare function report:delete-sample( $dirty-one as element()? ) {
  update delete $dirty-one,
  <Delete>insert</Delete>
};

(: ======================================================================
   Construct one row element to save in cached report
   ====================================================================== 
:)
declare function local:gen-sample-from-extract( $func, $valkey as xs:string, $aux as xs:string, $subject as element(), $object as element(), $pivot as element()? ) as element() {
  let $sample := $func($subject, $object, $pivot)
  return
    element { local-name($object) }
    {
      $sample/@Seal,
      attribute Key { $valkey },
      attribute Aux { $aux },
      attribute TS { current-dateTime() },
      normalize-space($sample)
    }
};

(: ======================================================================
   Utility to change or insert an attribute on a host node
   ====================================================================== 
:)
declare function local:set-attribute ( $host as element(), $name as xs:string, $value as xs:string ) {
  if (exists($host/@*[local-name() eq $name])) then
    update value $host/@*[local-name() eq $name] with $value
  else
    update insert attribute { $name } { $value } into $host
};

(: ======================================================================
   Local version of misc:save-content with no return data
   ======================================================================
:)
declare function local:save-content( $parent as element(), $legacy as element()?, $new as element()? ) as element()* {
  if ($new) then
    if ($legacy) then
      update replace $legacy with $new
    else
      update insert $new into $parent
  else
    ()
};

(: ======================================================================
   Gather the report from the dedicated collection and initialize it 
   lazily whether it was not yet created
   Pre: Collection /reports must exist and be both readable and writeable 
   Return the <Report> document root element or an <error> message
   ======================================================================
:)
declare function report:retrieve-report($report as element(), $reset as xs:boolean) as element() {
  let $cache-file := concat($report/@No, '.xml')
  return
    if (not($reset) and fn:doc-available(concat('/db/sites/cctracker/reports/', $cache-file))) then
      fn:doc(concat('/db/sites/cctracker/reports/', $cache-file))/*
    else
      let $report := <Report No="{$report/@No}" Title="{$report/Title}"/>
      let $stored-path := system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:store('/db/sites/cctracker/reports', $cache-file, $report))
      return
        if(not($stored-path eq ())) then
        (
          if ((xdb:get-group('/db/sites/cctracker/reports', $cache-file) ne 'users')
              or (xdb:get-owner('/db/sites/cctracker/reports', $cache-file) ne 'admin')) then
            system:as-user(account:get-secret-user(), account:get-secret-password(), compat:set-owner-group-permissions(concat('/db/sites/cctracker/reports', '/', $cache-file), 'admin', 'users', "rwxrwxr-x"))
          else
            (),
          fn:doc(concat('/db/sites/cctracker/reports/', $cache-file))/*
        )
        else
          <error>{ concat('/db/sites/cctracker/reports/', $cache-file, ' cannot be created') }</error>
};

(: ======================================================================
   Implement side effects to signal start of a reporting computation
   ====================================================================== 
:)
declare function local:start-reporting( $cached as element(), $meta as element() ) {
  local:set-attribute($cached, 'StartGeneration', string(current-dateTime())),
  local:set-attribute($cached, 'Duration', '...'),
  local:set-attribute($meta, 'Running', $cached/@No),
  (: create new Error log container :)
  local:save-content($meta, $meta/Errors[@ReportRef eq $cached/@No],
    <Errors ReportRef="{ $cached/@No }" TS="{ string(current-dateTime()) }"/>)
};

(: ======================================================================
   Implement side effects to signal termination of a reporting computation
   ====================================================================== 
:)
declare function local:stop-reporting( $cached as element(), $meta as element(), $start,  $error as xs:string? ) {
  (: compute and save duration :)
  let $runtimems := ((util:system-time() - $start) div xs:dayTimeDuration('PT1S'))
  return
    local:set-attribute($cached, 'Duration', $runtimems),
  (: report termination satus :)
  if ($error) then (
    local:set-attribute($cached, 'LastRun', 'err'),
    local:set-attribute($meta, 'Running', '*'),
    report:log-error($cached/@No, $error)
    )
  else (
    local:set-attribute($cached, 'LastRun', 'ok'),
    local:set-attribute($meta, 'Running', '-')
    )
};

(: ======================================================================
   Compute the targeted report for the requested range adding/deleting
   samples in the cached Report. Return an empty <Report> with some stats.
   Pre-condition : DO NOT run it in // on the same report !
   ======================================================================
:)
declare function local:report-update( $report as element(), $cached as element(), $min as xs:double?, $max as xs:double? ) as element() {
  let $freshness := xs:dayTimeDuration(miscellaneous:get-property('reports', 'freshness', 'PT86400S'))
  let $total := count($cached/*)
  return
    <Report>
      { 
      let $sample-report := function-lookup(xs:QName(concat("sample:gen_report_", $report/@No)), 5)
      let $res := $sample-report($cached, $report, $min, $max, $total eq 0)
      (: to define more stats attributes, generate them in report:make-sample :)
      let $hit := count($res[. eq 'hit'])
      let $insert := count($res[. eq 'insert'])
      let $replace := count($res[. eq 'replace'])
      let $delete := count($res[. eq 'delete'])
      return (
        attribute { 'Insert' } { $insert },
        attribute { 'Replace' } { $replace },
        attribute { 'Delete' } { $delete },
        local:set-attribute($cached, 'Hit', $hit),
        local:set-attribute($cached, 'Insert', $insert),
        local:set-attribute($cached, 'Replace', $replace),
        local:set-attribute($cached, 'Delete', $delete),
        local:set-attribute($cached, 'Freshness', $freshness)
        (: TODO: pivotable rows are deleted by calling report:delete-sample but not orphans rows
           -  see how to detect deleted orphans rows (e.g. deleted Case) and delete them :)
        )
      }
    </Report>
};

(: ======================================================================
   Wrapper function to check no other report generation is in progress 
   and to call report update fuction. Log exceptions in meta.xml file.
   Return an <error> message, a <Report> summary on success or nothing.
   ======================================================================
:)
declare function report:run( $report as element()?, $cached as element(), $min as xs:double?, $max as xs:double? ) as element()? {
  if (local-name($cached) eq 'error') then
    $cached
  else
    let $meta := fn:doc(concat($globals:reports-uri, '/', 'meta.xml'))/Meta
    let $start := util:system-time()
    return
      if (some $c in fn:collection($globals:reports-uri)/Report satisfies $c/@Duration eq '...') then
        <error>A report generation is already in progress, you can only run one at a time, please wait until it terminates</error>
      else
        try {
          local:start-reporting($cached, $meta),
          local:report-update($report, $cached, $min, $max),
          local:stop-reporting($cached, $meta, $start, ())
        }
        catch * {
          local:stop-reporting($cached, $meta, $start, concat('Caught error ', $err:code, ' : ', $err:description))
        }
};

(: ======================================================================
   Excel role creation from sequence
   ====================================================================== 
:)
declare function report:create-row(
  $values as xs:anyAtomicType*
) as element(ms:row)
{ 
  <ms:row>
  {
    for $val at $v in $values  
    return
      if($val castable as xs:integer or $val castable as xs:double) then     
        <ms:c>
          <ms:v>{$val}</ms:v>
        </ms:c>
      else
        <ms:c t="inlineStr"> 
          <ms:is>
            <ms:t>{$val}</ms:t>
          </ms:is>
        </ms:c>
  }
  </ms:row>
};

(: ====================================================================== 
   Used for rendering package file (.xlsx) through epilogue
   ======================================================================
:)
declare function report:extract-sheet( $cached as element(), $report as element() ) as element(ms:sheetData) {
  let $fn := replace(replace(lower-case($report/Title), '[\(\)]', ''), ' ', '-')
  let $headers-name :=
    for $s in $report/Sample/child::*
    return excel:camel-case-to-words(local-name($s))
    
  let $columncount := fn:count($headers-name)
  let $headers := excel:create-row($headers-name)
  let $field-separator := $report/Sample/@FieldSeparator (: optional, usually to embed free text in exports :)
  let $fs := if ($field-separator) then 
               if ($field-separator = $report:fs-regexp-escape) then
                 concat('\', $field-separator)
               else
                 $field-separator
               else 
                 ','
  return <ms:sheetData fn="{$fn}">{$headers, for $s in $cached//* return report:create-row(tokenize($s, $fs))}</ms:sheetData>
};

