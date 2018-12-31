xquery version "1.0";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";

declare option exist:serialize "method=text media-type=text/plain";

(: ======================================================================
   Returns a list of nutscodes for the enterprise 
   Returns the empty sequence if enterprise, postal code or country missing
   Returns ('-1', postal code prefix, country) in no matching nuts
   TODO: factorize with calls/assign.xqm
   ======================================================================
:)
declare function local:nuts-from-postcode( $e as element()? ) as xs:string* {
  if ($e//PostalCode and $e//Country) then
    let $country := $e//Country/text()
    let $country-table := fn:collection('/db/sites/nuts')//Nuts[@Country eq $country]
    let $prefix :=
      if ($country-table[@Index eq 'Nuts']) then (: tries to use 3 chars precision :)
        let $start := substring($e//PostalCode/text(), 1, 3)
        return
          if (ends-with($start, ' ')) then normalize-space($start) else $start
      else (: 2 chars precision enough :)
        (:substring($e//PostalCode/text(), 1, 2):)
        substring(replace($e//PostalCode/text(), "[^\d]", ""), 1, 2)
    return
      let $res :=
        if ($country-table[@Index eq 'Nuts']) then
          $country-table/Code[contains(Postals, $prefix)]/Nuts/text()
        else
          distinct-values(
            for $c in $country-table/Code[Postal eq $prefix]
            order by number($c/Err) descending
            return $c/Nuts/text()
          )
      return
        if (not(empty($res))) then $res else ('-1', if ($prefix) then $prefix else 'null', if ($country) then $country else 'null')
  else
    ()
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $case-no := tokenize($cmd/@trail, '/')[2]
let $case := fn:collection($globals:cases-uri)/Case[No = $case-no]
return
  if ($case) then
    let $nuts := local:nuts-from-postcode($case/Information/ClientEnterprise)
    return
      if (empty($nuts)) then
        "Postal code or Country for SME Beneficiary not found"
      else if ($nuts[1] eq '-1') then
        concat($nuts[3], ' (postal code prefix "', $nuts[2], '" not found in tables, fallback to country code)')
      else
        string-join((concat('[', $nuts[1], ']'), subsequence($nuts, 2)), ", ")
  else
    "Case not found"
