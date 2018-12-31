xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utilities to assign cases to EEN Regional Entities

   April 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace assign = "http://oppidoc.com/ns/cctracker/assign";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

(: ======================================================================
   Converts an enterprise PostalCode to a list of nutscodes
   Falls back to the country code
   ======================================================================
:)
declare function local:nuts-from-postal( $e as element()? ) as xs:string* {
  let $country := $e/Address/Country/text()
  let $country-table := fn:collection('/db/sites/nuts')//Nuts[@Country eq $country]
  let $prefix :=
    if ($country-table[@Index eq 'Nuts']) then (: tries to use 3 chars precision :)
      let $start := substring($e/Address/PostalCode/text(), 1, 3)
      return
        if (ends-with($start, ' ')) then normalize-space($start) else $start
    else (: 2 chars precision enough :)
      (:substring($e/Address/PostalCode/text(), 1, 2):)
      substring(replace($e/Address/PostalCode/text(), "[^\d]", ""), 1, 2)
  let $res :=
    if ($e/Address/PostalCode and $country) then
      if ($country-table[@Index eq 'Nuts']) then
        $country-table/Code[contains(Postals, $prefix)]/Nuts/text()
      else
        distinct-values(
          for $c in $country-table/Code[Postal eq $prefix]
          order by number($c/Err) descending (: uses Err (confidence level) the higher the more precise :)
          return $c/Nuts/text()
        )
    else
      ()
  return
    if (empty($res)) then $country else $res
};

declare function local:suggest-iter( $car as xs:string?, $cdr as xs:string*, $regions as element() ) as element()* {
  if (empty($car)) then 
    $car
  else
    let $found := 
      for $p in $regions/Region
      where (some $x in $p/NutsCodes/Nuts satisfies starts-with($car, $x))
      return $p
    return
      if (exists($found)) then
        $found
      else
        local:suggest-iter($cdr[1], subsequence($cdr, 2), $regions)
};

(: ======================================================================
   Returns a list of region Option elements for EEN regions matching a case
   Matching is based on nuts code (level 1 or level 2)
   ======================================================================
:)
declare function assign:suggest-region ( $case as element()?, $lang as xs:string ) as element()* {
let $nuts := local:nuts-from-postal($case/../../Information/Beneficiaries/(Coordinator | Partner)[PIC eq $case/PIC])
  return
    if (count($nuts) > 0) then
      let $defs := <Regions>{ fn:collection($globals:regions-uri)/Region }</Regions>
      return
        let $check-country := (count($nuts) eq 1) and (string-length($nuts[1]) eq 2) and (count($defs/Region[Address/Country = $nuts]) > 0)
          (: 3rd condition in case the country is covered by an EEN in another country :)
        return 
        let $res :=
          if ($check-country) then
            for $p in $defs/Region[Address/Country = $nuts]
            return $p
          else (: new algorithm stops at first ordered nuts that matches :)
            local:suggest-iter($nuts[1], subsequence($nuts, 2), $defs)
        return
          if (not(empty($res))) then
            $res
          else
            let $country := $case/../../Information/Beneficiaries/(Coordinator | Partner)[PIC eq $case/PIC]/Address/Country
            return
              <error>{ concat('no EEN Entity recorded for ',
                string-join($nuts, ', '), if ($country) then concat(' (', display:gen-name-for('Countries', $country, 'en'), ')') else ())  }</error>
    else
      <error>could not identify a nuts for case</error> 
};

declare function assign:suggest-region-from-enterprise( $e as element()?, $lang as xs:string ) as element()* {
  let $nuts := local:nuts-from-postal($e)
  return
    if (count($nuts) > 0) then
      let $defs := <Regions>{ fn:collection($globals:regions-uri)/Region }</Regions>
      return
        let $check-country := (count($nuts) eq 1) and (string-length($nuts[1]) eq 2) and (count($defs/Option[Country = $nuts]) > 0)
          (: 3rd condition in case the country is covered by an EEN in another country :)
        let $res :=
          if ($check-country) then
            for $p in $defs/Region[Country = $nuts]
            return $p
          else (: new algorithm stops at first ordered nuts that matches :)
            local:suggest-iter($nuts[1], subsequence($nuts, 2), $defs)
        return
          if (not(empty($res))) then
            $res
          else
            let $country := $e/Address/Country
            return
              <error>{ concat('no EEN Entity recorded for ',
                string-join($nuts, ', '), if ($country) then concat(' (', display:gen-name-for('Countries', $country, 'en'), ')') else ())  }</error>
    else
      <error>could not identify a nuts for case</error>
};


