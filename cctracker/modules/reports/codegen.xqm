xquery version "3.1";
(: WARNING: importing stats module (which import oppidum) may not be possible  when called from a scheduled job 
   since oppidum is making use of HTTP request object which is not available :)

module namespace codegen = "http://oppidoc.com/ns/cctracker/codegen";

declare variable $codegen:crlf := codepoints-to-string((10));

declare variable $codegen:xquery-header := concat("xquery version '3.0';

(: Generated on ", current-dateTime(), " please do not edit :)

module namespace sample = 'http://oppidoc.com/ns/cctracker/sample';

import module namespace globals = 'http://oppidoc.com/oppidum/globals' at '../lib/globals.xqm';
import module namespace display = 'http://oppidoc.com/oppidum/display' at '../lib/display.xqm';
import module namespace misc = 'http://oppidoc.com/ns/cctracker/misc' at '../lib/util.xqm';
import module namespace stats = 'http://oppidoc.com/ns/cctracker/stats' at '../modules/stats/stats.xqm';
import module namespace report = 'http://oppidoc.com/ns/cctracker/reports' at '../modules/reports/report.xqm';
");

(: ======================================================================
   Core function of the report generation algorithm: generate single 
   sample on orphan extract or multiple samples on pivotable extract
   ====================================================================== 
:)
declare variable $codegen:sample-gen_report := <String><![CDATA[declare function sample:gen_report_@@NO@@ ( $cached as element()?, $report as element(), $min as xs:double?, $max as xs:double?, $bootstrap as xs:boolean ) as element()* {
  let $target := $report/Target
  let $samplify := function-lookup(xs:QName(concat('sample:report_', $report/@No)), 3) (: sample generation function :)
  let $extracts-path := concat('fn:collection("/db/sites/cctracker/', $target/Subject/@Collection, '")', $target/Object)
  let $pivot-path := concat('$object/', $target/Pivot/@Parent, '/', $target/Pivot)
  let $nolimit := ($max eq -1)
  let $incl-orphan := empty($target/Object/@Include) or $target/Object/@Include ne 'no'
  let $orphan-nb := if ($incl-orphan) then 1 else 0
  return
    for $object at $i in util:eval($extracts-path)
    let $subject :=  @@SUBJECT@@ (: SUBJECT :)
    let $pivot := ()
    let $index-pivot := '-1'
    let $valkey := @@OBJKEY@@ (: OBJKEY :)
    let $hit := $cached//*[@Key eq $valkey]
    let $dirty := exists($hit) and report:expired(fn:head($hit))
    where $i >= $min and ($nolimit or $i <= $max)
    return 
      if ($bootstrap or empty($hit) or $dirty) then
        try {
          let $pivotable := util:eval($pivot-path)
          let $pre-size := count($hit) (: how many rows to replace :)
          let $post-size := if ($pivotable) then count($pivotable) else $orphan-nb (: how many rows to delete afterward :)
          return (
            (: replace or insert new rows :)
            if ($pivotable) then
              for $pivot at $i in $pivotable
              let $index-pivot := @@PIVKEY@@ (: PIVKEY :)
              return
                report:make-sample($hit[$i], $samplify, $cached, $valkey, $index-pivot, $subject, $object, $pivot)
            else if ($incl-orphan) then
              report:make-sample($hit[1], $samplify, $cached, $valkey, $index-pivot, $subject, $object, $pivot)
            else  
              (),
            (: delete unused rows :)
            if ($pre-size > 0) then
              for $sample in $hit[$pre-size + 1 to $post-size]
              return report:delete-sample($sample)
            else
              ()
            )
          } catch * {
            report:log-error($report/@No, concat('Caught error ', $err:code, ': ', $err:description,
              ' while generating sample with key: ', $valkey, ' at index ', $i))
            (: NOTE: if error happens on a pivoted sample it won't be recomputed until pivot expired or rest :)
          }
      else
        <Hit>hit</Hit>
};
]]></String>;

declare function local:gen-verbatim( $verbatim as element()? ) {
  if ($verbatim) then
    concat(
      replace(util:serialize($verbatim, "method=text"), "\s*$", ''),
      $codegen:crlf
    )
  else
    ()
};

declare function local:gen-gen-report( $report as element() ) {
  replace(
    string-join(
      tokenize(
        string-join(
          tokenize(
            string-join(
              tokenize(
                $codegen:sample-gen_report,
                '@@SUBJECT@@'), 
              string($report/Target/Subject)
            ),
            '@@OBJKEY@@'), 
          string($report/Target/Object/@Key)
        ),
      '@@PIVKEY@@'),
      string($report/Target/Pivot/@Key)
    ),
    '@@NO@@', 
    $report/@No
    )
};

(: Variable substitution :)
declare function local:replace-multi( $arg as xs:string?, $changeFrom as xs:string*, $changeTo as xs:string* ) as xs:string? {
  if (count($changeFrom) > 0) then 
    local:replace-multi(
      replace($arg, $changeFrom[1], if (exists($changeTo[1])) then $changeTo[1] else ()),
        $changeFrom[position() > 1],
        $changeTo[position() > 1])
  else 
    $arg
};

(: ======================================================================
   Generate code string to evaluate an expression
   ====================================================================== 
:)
declare function local:evaluate( $column as element(), $froms as xs:string*, $tos as xs:string* ) as xs:string {
  let $sel-prefix := if ($column/@selector) then concat('display:gen-brief-for("',$column/@selector , '", ') else ()
  let $ren-prefix := if ($column/@render) then concat($column/@render, '(') else ()
  let $prefix := fn:head(($ren-prefix, $sel-prefix)) (: @render has priority over @selector :)
  let $suffix := if ($prefix) then ')' else ()
  return
    concat(
      "      let $res := ", $prefix, local:replace-multi($column/Expression, $froms, $tos), $suffix, $codegen:crlf,
      "      return", $codegen:crlf,
      "        if ($res) then", $codegen:crlf,
      "          $res", $codegen:crlf,
      "        else", $codegen:crlf,
      "          ''"
    )
};

(: ======================================================================
   Implement Bind element in Unification in Report
   ====================================================================== 
:)
declare function local:bind( $bindings as element()* ) as xs:string? {
  if ($bindings) then
    concat(
      string-join(
        for $b in $bindings
        return concat("  let ", $b/@Variable, " := ", $b/@Is),
        $codegen:crlf
      ), 
      $codegen:crlf)
  else
    ()
};

(: ======================================================================
   Implement optional Seal Expression (local binding)
   ====================================================================== 
:)
declare function local:seal-let( $report as element(), $froms as xs:string*, $tos as xs:string* ) as xs:string? {
  if ($report/Seal/Expression) then
    concat("  let $seal := ", local:replace-multi($report/Seal/Expression, $froms, $tos), $codegen:crlf)
  else
     ()
};

(: ======================================================================
   Implement optional Seal Expression (Seal attribute generation)
   ====================================================================== 
:)
declare function local:seal-return( $report as element()  ) as xs:string? {
  if ($report/Seal/Expression) then
    concat("    if ($seal) then attribute { 'Seal' } { '1' } else (),", $codegen:crlf)
  else
    ()
};

declare function local:functionalize( $report as element(), $froms as xs:string*, $tos as xs:string* ) as xs:string {
    let $sample := fn:doc('/db/www/cctracker/config/reports.xml')//Report[@No eq $report/@No]/Sample
    return 
        string-join(
            (
            $codegen:crlf,
            concat("declare function sample:report_", $report/@No, " ($subject, $object, $pivot) { "), $codegen:crlf,
            local:bind($report/Unification/Bind),
            local:seal-let($report, $froms, $tos),
            if ($report/Unification/Bind or $report/Seal/Expression) then
              concat("  return", $codegen:crlf)
            else
              (),
            "  <Sample>", $codegen:crlf,
            "    {", $codegen:crlf,
            local:seal-return($report),
            "    string-join((", $codegen:crlf,
            string-join(
              for $s in $sample/*
              return
                  if ($s/Expression) then 
                    local:evaluate($s, $froms, $tos)
                  else if ($s/@Variable) then
                    let $var := fn:head(fn:doc('/db/www/cctracker/config/variables.xml')//Variable[Name eq $s/@Variable])
                    return
                      if ($var) then
                        local:evaluate($var, $froms, $tos)
                      else
                        concat('NOT-FOUND[', $s/@Variable, ']')
                  else
                    (),
              concat(',', $codegen:crlf)),
            concat("    ), '", ($sample/@FieldSeparator, ',')[1], "')"), $codegen:crlf,
            "    }", $codegen:crlf,
            "  </Sample>", $codegen:crlf,
            "};"
            )
        )
};

declare function codegen:deploy-reports () {
  let $reports := fn:doc('/db/www/cctracker/config/reports.xml')/Reports
  let $filename := "webapp/projects/cctracker/gen/sample.xqm"
  let $buffer := <Buffer>{concat(
    $codegen:xquery-header,
    local:gen-verbatim($reports/Verbatim),
    string-join(
      for $report in $reports/Report
      let $froms := for $v in $report/Unification/Substitution return replace(string($v/@Variable), '(\$)', '\\$1')
      let $tos := for $v in $report/Unification/Substitution return replace(string($v/@Is), '(\$)', '\\$1')
      return (
        local:gen-verbatim($report/Verbatim),
        local:gen-gen-report($report),
        local:functionalize($report, $froms, $tos)
        ),
      $codegen:crlf
      )
    )
    }
    </Buffer>
  return
    if (file:serialize($buffer/text(), $filename, "method=text")) then
      $filename
    else 
      concat("ERROR ", $filename, " NOT SAVED")
};
