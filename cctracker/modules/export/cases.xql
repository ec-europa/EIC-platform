xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Cases exportation facility

   TODO: full JSON / d3 version to lower bandwidth ?

   April 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)
   
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";


(: ======================================================================
   Rewrites the Goto URL to absolute path using command's base URL
   This way the redirection is independent from the reverse proxy in prod or test
   ======================================================================
:)
declare function local:rewrite-goto-url ( $cmd as element(), $url as xs:string? ) as xs:string {
  let $startref := fn:doc(oppidum:path-to-config('mapping.xml'))/site/@startref
  return
    if ($url and (substring-after($url, $cmd/@base-url) ne $startref)) then
      if (not(starts-with($url, '/'))) then
        concat($cmd/@base-url, $url)
      else 
        $url
    else (: overwrites startref redirection or no explicit redirection parameter :)
      let $goto := fn:doc(oppidum:path-to-config('settings.xml'))/Settings/Module[Name eq 'login']/Property[Key eq 'startref']
      return
        if ($goto) then
          concat($cmd/@base-url, $goto/Value)
        else
          concat($cmd/@base-url, $startref)
};

(: ======================================================================
   Generates an informative "Undefined Call" message
   TODO: factorize with calls/assign.xql (calls.xqm ?)
   ======================================================================
:)
declare function local:error-msg ( $target as xs:string ) as xs:string {
  concat('Undefined Call "', $target, '"', ' known Calls are : ',
    string-join(
      for $o at $i in fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'CallRollOuts']/Option
      return concat('"', $i, '"', ' (', $o/Date/text(), ' Phase ', $o/PhaseRef/text(), ')'),
      ", "
      )
    )
};

(: ======================================================================
   Converts target token to (Call, PhaseRef) pair of strings or "Undefined Call"
   TODO: factorize with calls/assign.xql (calls.xqm ?)
   ======================================================================
:)
declare function local:get-call( $target as xs:string ) as xs:string* {
  if (matches($target, '^\d+$')) then
    let $spec := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'CallRollOuts']/Option[number($target)]
    return
      if ($spec) then
        ($spec/Date/text(), $spec/PhaseRef/text())
      else
        local:error-msg($target)
  else if ($target eq 'all') then
    $target
  else
    local:error-msg($target)
};

declare function local:gen-name-coach( $ref as xs:string?, $all as xs:boolean ) as element()+ {
  if ($ref) then
    let $p := fn:collection($globals:persons-uri)//Person[Id = $ref]
    return (
      <Coach>
        {
        if ($p) then
          concat($p/Name/LastName, ' ', $p/Name/FirstName)
        else if ($ref eq 'import') then
          "case tracker importer"
        else
          display:noref($ref, 'en')
        }
      </Coach>,
      if ($all) then
        <Cm>{ $p/Contacts/Email/text() }</Cm>
      else
        ()
      )
  else 
    <Coach/>
};

declare function local:gen-name-kam( $ref as xs:string?, $all as xs:boolean ) as element()+ {
  if ($ref) then
    let $p := fn:collection($globals:persons-uri)//Person[Id = $ref]
    return (
      <KAM>
        {
        if ($p) then
          concat($p/Name/LastName, ' ', $p/Name/FirstName)
        else if ($ref eq 'import') then
          "case tracker importer"
        else
          display:noref($ref, 'en')
        }
      </KAM>,
      if ($all) then
        <Km>{ $p/Contacts/Email/text() }</Km>
      else
        ()
      )
  else 
    <KAM/>
};

declare function local:gen-email-officer( $ref as xs:string? ) as element()+ {
  if ($ref) then
    let $p := fn:collection($globals:persons-uri)//Person[Id = $ref]
    return (
      <Pm>{ $p/Contacts/Email/text() }</Pm>
      )
  else 
    ()
};

declare function local:gen-tag( $name as xs:string, $val as xs:string? ) {
  if ($val) then
    element { $name } { $val }
  else 
    ()
};

(: ======================================================================
   note: since february 2016 "kam-grant-signature" e-mail discontinued (KN)
   ====================================================================== 
:)
declare function local:gen-case-sample( $case as element(), $all as xs:boolean ) as element() {
  <Case>
    {
    if ($all) then (
      local:gen-tag('PH', $case/Information/Call/PhaseRef),
      local:gen-tag('Call', $case/Information/Call/Date),
      local:gen-tag('S', $case/StatusHistory/CurrentStatusRef),
      local:gen-email-officer($case/Information/ProjectOfficerRef),
      let $tbd := 
          for $c in fn:collection($globals:checks-uri)//Case[@No eq $case/No][not(@ActivityNo)]
          return string($c/parent::Check/@No)
      return
        if (empty($tbd)) then () else <TBD>{ string-join($tbd, ", ") }</TBD>
      )
    else
      (),
    $case/No,
    $case/Information/ClientEnterprise/Address/Country,
    $case/Information/Acronym
    }
    <PID>{ string($case/@ProjectId) }</PID>
    <Date>{ substring($case/Information/Contract/Date/text(), 1, 10) }</Date>
    <SN>
      { 
      if ($case/Information/Contract/SME-Notification/Date) then
        substring($case/Information/Contract/SME-Notification/Date, 1, 10)
      else if ($case/Alerts/Alert[Key eq 'sme-1']) then
        substring($case/Alerts/Alert[Key eq 'sme-1'][1]/Date, 1, 10)
      else 
        (: TODO: temporary hack, TO BE REMOVED after migration :)
        let $m := $case/Alerts/Alert[(ActivityStatusRef eq '3') and (PreviousStatusRef eq '2') and Alert/Message/Text[ends-with(., ' paid directly by us.')]]
        return
          if ($m) then
            concat(substring($m/Date, 1, 10), ' (M)')
          else
            ()
      }
    </SN>
    <KN>{ substring($case/Information/Contract/KAM-Notification/Date/text(), 1, 10) }</KN>
    { local:gen-name-kam($case/Management/AccountManagerRef, $all) }
    {
    if ($case/NeedsAnalysis/Analysis/Date) then
      <NA>{ $case/NeedsAnalysis/Analysis/Date/text() }</NA>
    else
      ()
    }
    {
    for $a in $case//Activity
    let $date := $a/StatusHistory/Status[ValueRef eq '3']/Date
    let $hours := $a/FundingRequest/Budget/Tasks/TotalNbOfHours
    return
      <A>
        {
        if ($all) then (
          $a/No,
          <S>{ $a/StatusHistory/CurrentStatusRef/text() }</S>,
          let $tbd := 
            for $c in fn:collection($globals:checks-uri)//Case[@No eq $case/No][@ActivityNo eq $a/No]
            return string($c/parent::Check/@No)
          return
            if (empty($tbd)) then () else <TBD>{ string-join($tbd, ",") }</TBD>
          )
        else
          (),
        local:gen-name-coach($a/Assignment/ResponsibleCoachRef, $all),
        if ($a/FundingDecision/CoachContract) then (
          <Contract>
            { 
            concat($a/FundingDecision/CoachContract/*/Date, 
              ' (',
              substring(local-name($a/FundingDecision/CoachContract/*[1]), 1, 1),
               ')'
              )
            }
          </Contract>,
          <Pool>{ $a/FundingDecision/CoachContract/PoolNumber/text() }</Pool>
          )
        else if (not($all)) then (: to allow XSLT feedback:)
          (
          <Contract/>,
          <Pool/>
          )
        else
          ()
        }
        <CP>
          {(
          attribute Date {
            if ($date) then
              attribute Date { substring($date, 1, 10) }
            else
              'pending'
          },
          $hours/text()
          )}
        </CP>
      </A>
    }
  </Case>
};

let $cmd := request:get-attribute('oppidum.command')
let $target := tokenize($cmd/@trail, '/')[2]
let $call-phase := local:get-call($target)
let $call := $call-phase[1]
let $phase := $call-phase[2]
return
  if (starts-with($call, 'Undef')) then
    <Error>{ $call }</Error>
  else if ($call eq 'all') then
    (<Void/>,
    oppidum:redirect(local:rewrite-goto-url($cmd, 'reports/1.xlsx')))[1](:
    let $total := count(collection($globals:cases-uri)/Case[Information/Call])
    let $froms := request:get-parameter('from', 1)
    let $tos := request:get-parameter('to', ())
    let $from := if ($froms castable as xs:integer) then number($froms) else 1
    let $to := if ($tos castable as xs:integer) then number($tos) else $total
    return
      <Cases Total="{ $total }" From="{ $from }" To="{ $to }"
        Base="{ if (not(ends-with($cmd/@exist-path, '/'))) then '../..' else '../../..' }" 
        User="{ misc:gen-current-person-name() }" Date="{ substring(string(current-dateTime()), 1, 19) }"
        Call="{ $call }" Phase="all">
        {
        for $case in collection($globals:cases-uri)/Case[Information/Call]
        let $nb := number($case/No)
        where $nb >= $from and $nb <= $to
        order by number($case/No) ascending
        return local:gen-case-sample($case, true())
        }
      </Cases>:)
  else
    <Cases Total="{ count(collection($globals:cases-uri)/Case[Information/Call[Date eq $call][PhaseRef eq $phase]]) }"
      Base="{ if (not(ends-with($cmd/@exist-path, '/'))) then '../..' else '../../..' }" 
      User="{ misc:gen-current-person-name() }" Date="{ substring(string(current-dateTime()), 1, 19) }"
      Call="{ $call }" Phase="{ $phase }">
      {
      for $case in collection($globals:cases-uri)/Case[Information/Call[Date eq $call][PhaseRef eq $phase]]
      return local:gen-case-sample($case, false())
      }
    </Cases>
