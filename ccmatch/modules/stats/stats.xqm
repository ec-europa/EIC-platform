xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   January 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace stats = "http://oppidoc.com/ns/cctracker/stats";

declare namespace json="http://www.json.org";
declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "../suggest/match.xqm";

(: ======================================================================
   TODO: move to misc: ?
   ====================================================================== 
:)
declare function local:get-local-string( $lang as xs:string, $key as xs:string ) as xs:string {
  let $res := fn:doc($globals:dico-uri)/site:Dictionary/site:Translations[@lang = $lang]/site:Translation[@key = $key]/text()
  return
    if ($res) then
      $res
    else
      concat('missing [', $key, ', lang="', $lang, '"]')
};

declare function local:gen-values( $value as element()?, $literal as xs:boolean ) {
  <Values>
    {
    if ($literal) then 
      attribute { 'json:literal' } { 'true' }
    else
      (),
      $value/text()
    }
  </Values>
};

(: ======================================================================
   Generates code book for a Composition
   ====================================================================== 
:)
declare function stats:gen-composition-domain( $composition as element() ) as element()* {
  element { string($composition/@Name) }
  {
  for $m in $composition/Mean
  return
    <Labels>{ local:get-local-string('en', string($m/@loc)) }</Labels>,
  for $m in $composition/Mean
  return
    <Values>{ string($m/@Filter) }</Values>,
  for $m in $composition/Mean
  return
    <Legends>{ local:get-local-string('en', concat(string($m/@loc), '.legend')) }</Legends>
  }
};

(: ======================================================================
   Generates labels and values decoding book for a given selector name
   See also form:gen-selector-for in lib/form.xqm
   TODO: restrict to existing values in data set for some large sets (e.g. NOGA) ?
   FIXME: hard coded language parameter 'en'
   ====================================================================== 
:)
declare function stats:gen-selector-domain( $name as xs:string, $selector as xs:string, $literal as xs:boolean) as element()* {
  let $sel := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq $selector]
  return
    element { $name } {
      if ($sel/Group) then (: nested selector :)
        (
        for $v in $sel//Option
        let $concatWithId := starts-with($sel/@Label, 'V+')
        let $ltag := replace($sel/@Label, '^V\+', '')
        let $vtag := string($sel/@Value)
        return
          <Labels>
            { 
              if ($concatWithId) then
                concat($v/*[local-name(.) eq $vtag], ' - ', $v/*[local-name(.) eq $ltag])
              else
                $v/*[local-name(.) eq $ltag]/text()
            }
          </Labels>,
        for $v in $sel//Option
        let $tag := string($sel/@Value)
        return
          local:gen-values($v/*[local-name(.) eq $tag], $literal)
        )
      else (: flat selector :)
        (
        for $v in $sel/Option
        let $tag := string($sel/@Label)
        let $l := $v/*[local-name(.) eq $tag]/text()
        return
          <Labels>
            { 
            if (contains($l, "::")) then
              concat(replace($l, "::", " ("), ")")
            else 
              $l
            }
          </Labels>,
        for $v in $sel/Option
        let $tag := string($sel/@Value)
        return
          local:gen-values($v/*[local-name(.) eq $tag], $literal)
        )
    }
};

(: ======================================================================
   Stub to generates decoding books (labels, values) for a given selector
   ====================================================================== 
:)
declare function stats:gen-selector-domain( $name as xs:string, $selector as xs:string ) as element()* {
  stats:gen-selector-domain($name, $selector, false())
};

(: ======================================================================
   Generates decoding books (labels, values) for a given selector with 
   a specific format (i.e. literal)
   ====================================================================== 
:)
declare function stats:gen-selector-domain( $name as xs:string, $selector as xs:string, $format as xs:string? ) as element()* {
  stats:gen-selector-domain($name, $selector, not(empty($format)) and ($format eq 'literal'))
};

(: ======================================================================
   Generates labels and values decoding book for status of a given workflow name
   FIXME: hard coded language parameter 'en'
   ====================================================================== 
:)
declare function stats:gen-workflow-status-domain( $tag as xs:string, $name as xs:string ) as element()* {
  let $set := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']/WorkflowStatus[@Name eq $name]
  return
    element { $tag } {
      (
      for $v in $set/Status
      return
        <Labels>{ $v/Name/text() }</Labels>,
      for $v in $set/Status
      return
        <Values>{ $v/Id/text() }</Values>
      )
    }
};

(: ======================================================================
   Generates labels and values decoding book for a sequence of person's references
   This way the set can include persons who no longer hold the required role
   ======================================================================
:)
declare function stats:gen-persons-domain-for( $refs as xs:string*, $tag as xs:string ) as element()* {
  element { $tag }
    {
    (: Double FLWOR because of eXist 1.4.3 oddity see http://markmail.org/thread/mehfwoj6enc2z65v :)
    let $sorted := 
      for $p in fn:doc($globals:persons-uri)/Persons/Person[Id = $refs]
      order by $p/Name/LastName
      return $p
    return
      for $s in $sorted 
      return (
        <Labels>{ concat(normalize-space($s/Name/LastName), ' ', normalize-space($s/Name/FirstName)) }</Labels>,
        <Values>{ $s/Id/text() }</Values>
        )
    }
};

(: ======================================================================
   Generates years values for a sample set
   NOTE: Year tag name MUST BE consistent with stats.xml
   FIXME: could be directly computed client-side from the set (?)
   ======================================================================
:)
declare function stats:gen-year-domain( $set as element()* ) as element()* {
  for $y in distinct-values($set//Yr)
  where matches($y, "^\d{4}$")
  order by $y
  return
    <Yr>{ $y }</Yr>
};

(: ======================================================================
   Generates nuts values for a sample set
   NOTE: Nuts tag name consistent with stats.xml
   FIXME: could be directly computed client-side from the set (?)
   ======================================================================
:)
declare function stats:gen-nuts-domain( $set as element()* ) as element()* {
  for $y in distinct-values($set//Nuts)
  order by $y
  return
    <Nuts>{ $y }</Nuts>
};

(: ======================================================================
   Generates region values for a sample set
   NOTE: Region tag name consistent with stats.xml
   FIXME: could be directly computed client-side from the set (?)
   ======================================================================
:)
declare function stats:gen-regions-domain( $set as element()* ) as element()* {
  <EEN>
    {
    for $y in distinct-values($set//EEN)
    where $y ne ''
    order by $y
    return (
      <Labels>
        {
        if ($y ne '') then 
          display:gen-name-for('RegionalEntities', <t>{ $y }</t>, 'en')
        else 
          "undefined" 
        }
      </Labels>,
      <Values>{ $y }</Values>
      )
    }
  </EEN>
};

(: ======================================================================
   Generates labels and values decoding book for case impact variable with name and id
   ====================================================================== 
:)
declare function stats:gen-case-vector( $name as xs:string, $id  as xs:string ) {
  let $set := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Section[Id eq $id]
  return
    element { $name } {
      (
      for $v in $set/SubSections/SubSection
      return
        <Labels>{$v/SubSectionName/text()}</Labels>,
      for $v in $set/SubSections/SubSection
        return
        <Values>{$v/Id/text()}</Values>
      )
    }
};

(: ======================================================================
   Returns a list of weight vectors tag name to look for inside Activity
   Sample output: 'Vectors-1', 'Vectors-7'
   ====================================================================== 
:)
declare function stats:encode-needs-weight( $filter as element(), $root as xs:string ) as xs:string* {
  let $prefix := substring($root, 1, string-length($root) - 1) 
  let $filter-top-tag := concat('Weight', $root)
  let $filter-var-tag := concat($prefix, 'Ref')
  return
    for $c in $filter/*[local-name(.) eq $filter-top-tag]/*[local-name(.) eq $filter-var-tag]
    return 
    concat($root, '-', $c)
};

(: ======================================================================
   Converts zero or one element into xs:double value, returns 0 if empty or non-number
   FIXME: share with workflow/final-report.xql (?)
   ======================================================================
:)
declare function stats:as-number( $n as element()? ) {
  let $res := number($n)
  return
    if (string($res) eq 'NaN') then
      0
    else
      $res
};

(: ======================================================================
   Converts zero or one element into xs:double valuscore, returns 0 if empty or non-number
   Reverses scale so that 1 is least positive evaluation and 5 is most positive
   ======================================================================
:)
declare function stats:as-score( $n as element()? ) {
  let $res := number($n)
  return
    if (string($res) eq 'NaN') then
      0
    else
      -$res + 6
};

(: ======================================================================
   See also: stats:check-min-max in Case Tracker stats/stats.xqm
   ====================================================================== 
:)
declare function stats:check-min-max( $c as element(), $host as xs:string, $perf-min as xs:double, $perf-max as xs:double ) as xs:boolean {
  let $score := match:get-score-for('SME', $c, $host)
  return ($score ne 0) and ($perf-min <= $score) and ($score <= $perf-max)
};

(: ======================================================================
   Utility to return expertise level from submitteded criteria with name XXX
   Implements 'Expertise-XXX' convention on tag name to extract criteria from submitted filter
   ====================================================================== 
:)
declare function stats:get-expertise-for($filter as element(), $name as xs:string ) as xs:string* {
  let $expertise := $filter//*[local-name(.) eq concat('Expertise-', $name)]
  return
      if ($expertise eq 'high') then '3' else ('2', '3')
};
