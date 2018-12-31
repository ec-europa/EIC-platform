xquery version "3.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Reports engine API :

   - GET reindex to reindex the reports cache collection
   - GET nb.xlsx to generate Excel
   - POST nb to run report generation

   Redirects to /reports upon successful execution or throws an <error>
   except for .xlsx format for which it returns <ms:sheetData> data 
   to be streamed as Excel file in epilogue

   Decemeber 2018 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace report = "http://oppidoc.com/ns/cctracker/reports" at "report.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:as-number( $n as xs:string?, $default as xs:double ) {
  let $res := number($n)
  return
    if (string($res) eq 'NaN') then
      $default
    else
      $res
};

(: *** MAIN ENTRY POINT *** :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $report-no := tokenize($cmd/@trail, '/')[2]
let $format := string($cmd/@format)
let $min := local:as-number(request:get-parameter('min', 0), 0)
let $max := local:as-number(request:get-parameter('max', 'no limit'), -1)
let $reset := request:get-parameter('c', '0') eq '1'
let $report := fn:doc(oppidum:path-to-config('reports.xml'))//Report[@No eq $report-no]
return

  (: GET reports/reindex :)
  if ($report-no eq 'reindex') then (
    xdb:reindex($globals:reports-uri),
    oppidum:add-message('INFO', 'Reindexed reports cache', true()),
    <Redirected>{ oppidum:redirect(concat($cmd/@base-url, 'reports')) }</Redirected>
    )[last()]

  else if (empty($report)) then
    oppidum:throw-error('URI-NOT-FOUND', ())

  (: GET for Excel export:)
  else if ($format eq 'xlsx') then
    let $cached := fn:collection('/db/sites/cctracker/reports')/Report[@No eq $report-no]
    return 
      if ($cached) then
        report:extract-sheet($cached, $report)
      else
        oppidum:throw-error('CUSTOM', 'You must run a report generation first')

  (: POST run report computation
     add messages and errors to the flash so this is supposed to be called from a GUI with page redirection :)
  else if ($m eq 'POST') then
    let $done := report:run($report, report:retrieve-report($report, $reset), $min, $max)
    return (
      if (local-name($done) eq 'error') then 
        oppidum:add-error('CUSTOM', $done, true())
      else
        oppidum:add-message('INFO', 'Report update done, see stats below', true()),
      <Redirected>{ oppidum:redirect(concat($cmd/@base-url, 'reports?min=', $min, if ($max eq -1) then () else concat('&amp;max=', $max))) }</Redirected>
    )[last()]

  else 
    oppidum:throw-error('URI-NOT-FOUND', ())
    
