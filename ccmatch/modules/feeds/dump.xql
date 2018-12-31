xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Utility to dump feeds stats (useful to compare before / after full recomputation)

   Since July 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";

declare option exist:serialize "method=xml media-type=application/xml encoding=utf-8 indent=yes";

let $range := tokenize(request:get-parameter('r', ''), ',')
let $inf := if (exists($range)) then number($range[1]) else ()
let $sup := if (exists($range)) then number($range[2]) else ()
return
  <Feeds Inf="{ $inf }" Sup="{ $sup }">
    {
    for $feed in fn:collection($globals:persons-uri)//Person//Feeds/Feed[@For eq '1']
    let $user := $feed/ancestor::Person
    let $ri := $feed/Stats/Mean[@For eq 'RI']
    let $bi := $feed/Stats/Mean[@For eq 'BI']
    let $i := $feed/Stats/Mean[@For eq 'I']
    let $sme := $feed/Stats/Mean[@For eq 'SME']
    where
          (empty($inf) or (number($user/Id) >= $inf))
      and (empty($sup) or (number($user/Id) < $sup))
    return
      if (count($feed/Evaluation) eq 0) then
        <User id="{ $user/Id }">
          { $feed/Period/Before/text() }
        </User>
      else
        <User id="{ $user/Id }" perf="{ $feed/parent::Feeds/@Perf}" count="{count($feed/Evaluation)}" RI="{$ri/@Count}({$ri})" BI="{$bi/@Count}({$bi})" I="{$i/@Count}({$i})" SME="{$sme/@Count}({$sme})">
          { $feed/Period/Before/text() }
        </User>
    }
  </Feeds>
