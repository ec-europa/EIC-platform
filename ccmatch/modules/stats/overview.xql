xquery version "1.0";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";

(: Global :)
let $coaches := fn:collection($globals:persons-uri)//Person[Skills][UserProfile//FunctionRef = '4']
let $total1 := count($coaches)
let $acc-coaches := $coaches[Hosts/Host[@For eq '1']/AccreditationRef eq '4']
let $total2 := count($acc-coaches)
let $acc-order-coaches := $acc-coaches[Hosts/Host[@For eq '1']/WorkingRankRef eq '1']
let $total3 := count($acc-order-coaches)
(: Search by fit :)
let $total4 := count(
  $acc-order-coaches[not(Preferences/Coaching[@For eq '1']/YesNoAvailRef) or (Preferences/Coaching[@For eq '1']/YesNoAvailRef eq '1')]
  )
let $total5 := count(
  $acc-order-coaches[Preferences/Coaching[@For eq '1']/YesNoAvailRef eq '2']
  )
let $total6 := count(
  $acc-order-coaches[Preferences/Coaching[@For eq '1']/YesNoAvailRef eq '1']
  )
(: Search by criteria from Coach Match :)
let $total10 := count(
  $acc-order-coaches[Preferences/Visibility[@For eq '0']/YesNoAcceptRef eq '1']
  )
let $total11 := count(
  $acc-order-coaches[not(Preferences/Visibility[@For eq '0']/YesNoAcceptRef)]
  )
let $total12 := count(
  $acc-order-coaches[Preferences/Visibility[@For eq '0']/YesNoAcceptRef eq '2']
  )
(: Search by criteria from Case Tracker :)  
let $total20 := count(
  $acc-order-coaches[Preferences/Visibility[@For eq '1']/YesNoAcceptRef eq '1']
  )
let $total21 := count(
  $acc-order-coaches[not(Preferences/Visibility[@For eq '1']/YesNoAcceptRef)]
  )
let $total22 := count(
  $acc-order-coaches[Preferences/Visibility[@For eq '1']/YesNoAcceptRef eq '2']
  )
return
  <html>
    <body>
      <h1>Statistics</h1>
      <p>Coaches (with at least one skill) : { $total1 }</p>
      <p>Accredited for SME Instrument: { $total2 }</p>
      <p>Accredited for SME Instrument and in working order: <b>{ $total3 }</b></p>
      <h2>Search by fit from Case Tracker</h2>
      <p>Accredited and in working order and available or implicitly available : { $total4 }</p>
      <p>Accredited and in working order but explicitly not available : { $total5 }</p>
      <p>Total : { $total4 + $total5 }</p>
      <p>Accredited and in working order and explicitly available : { $total6 }</p>
      <h2>Search by criteria from Coach Match</h2>
      <p>Accredited and in working order and explicitly visible : { $total10 }</p>
      <p>Accredited and in working order and implicitly invisible : { $total11 }</p>
      <p>Accredited and in working order and explicitly invisible : { $total12}</p>
      <p>Total : { $total10 + $total11 + $total12 }</p>
      <h2>Search by criteria from Case Tracker</h2>
      <p>Accredited and in working order and explicitly visible : { $total20 }</p>
      <p>Accredited and in working order and implicitly invisible : { $total21 }</p>
      <p>Accredited and in working order and explicitly invisible : { $total22}</p>
      <p>Total : { $total20 + $total21 + $total22 }</p>
    </body>
  </html>
