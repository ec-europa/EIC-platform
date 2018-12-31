xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utility to dump coding variables used in dump functionality
   (while waiting for statistics availability)

   November 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=json media-type=text/plain";

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
  else
    local:error-msg($target)
};

(: ======================================================================
   TO BE DEPRECATED
   ======================================================================
:)
declare function local:gen-case-impact( $surname as xs:string, $name as xs:string ) as element()* {
  let $set := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/CaseImpact//Section[SectionRoot eq $name]
  let $id-node-name := 'Id'
  let $label-node-name := 'SubSectionName'
  return
    (
    for $v in $set/SubSections/SubSection
      return
        element { concat($surname, '_Values') }
          { $v/*[local-name(.) eq $id-node-name]/text() },
    for $v in $set/SubSections/SubSection
    return
    element { concat($surname, '_Labels') }
      {
      let $token := $v/*[local-name(.) eq $label-node-name]/text()
      return
        if (contains($token, ' (')) then
          substring-before($token, ' (')
        else
          $token
      }
    )
};

declare function local:gen-variable( $surname as xs:string, $name as xs:string, $label as xs:string?, $selector as xs:string, $option as xs:string ) as element()* {
  let $set := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/*[local-name(.) eq $selector][@Name eq $name]
  let $id-node-name := if ($set/@Value) then string($set/@Value) else 'Id'
  let $label-node-name := if ($label) then $label else if ($set/@Label) then string($set/@Label) else 'Name'
  return
    (
    for $v in $set/*[local-name(.) eq $option]
      return
        element { concat($surname, '_Values') }
          { $v/*[local-name(.) eq $id-node-name]/text() },
    for $v in $set/*[local-name(.) eq $option]
    return
    element { concat($surname, '_Labels') }
      {
      let $token := $v/*[local-name(.) eq $label-node-name]/text()
      return
        if (contains($token, ' (')) then
          substring-before($token, ' (')
        else
          $token
      }
    )
};

declare function local:gen-variable-regional-entities( $surname as xs:string, $label as xs:string? ) as element()* {
  let $set := <Selector Name="RegionalEntities" Value="Id" Label="Label" Test="EEN Entities">{fn:collection($globals:regions-uri)/Region}</Selector>
  let $id-node-name := if ($set/@Value) then string($set/@Value) else 'Id'
  let $label-node-name := if ($label) then $label else if ($set/@Label) then string($set/@Label) else 'Name'
  return
    (
    for $v in $set/*[local-name(.) eq 'Region']
      return
        element { concat($surname, '_Values') }
          { $v/*[local-name(.) eq $id-node-name]/text() },
    for $v in $set/*[local-name(.) eq 'Region']
    return
    element { concat($surname, '_Labels') }
      {
      let $token := $v/*[local-name(.) eq $label-node-name]/text()
      return
        if (contains($token, ' (')) then
          substring-before($token, ' (')
        else
          $token
      }
    )
};

declare function local:gen-variable( $surname as xs:string, $name as xs:string, $label as xs:string? ) as element()* {
  local:gen-variable($surname, $name, $label, 'Selector', 'Option')
};

(: ======================================================================
   2015 version for Agnieska - unplugged October 2016
   ====================================================================== 
:)
declare function local:gen-variables-2015() {
  <Variables>
    { local:gen-variable('CaseStatus', 'Case', 'Name', 'WorkflowStatus', 'Status') }
    { local:gen-variable('ActivityStatus', 'Activity', 'Name', 'WorkflowStatus', 'Status') }
    { local:gen-variable('Topics', 'Topics', 'ShortName') }
    { local:gen-variable('Size', 'Sizes', ()) }
    <!--
    <TargetedMarkets>{ string-join($enterprise//TargetedMarketRef/text(), $local:separator) }</TargetedMarkets>:)
    <DomainActivityRef>{ $enterprise/DomainActivityRef/text() }</DomainActivityRef>
    -->
    { local:gen-variable-regional-entities('RegionalEntityRef', 'Acronym') }
    { local:gen-variable('Tools', 'KnownTools', ()) }
    { local:gen-variable('SectorGroup', 'SectorGroups', ()) }
    { local:gen-variable('SectorGroup', 'SectorGroups', ()) }
    { local:gen-variable('InitialContext', 'InitialContexts', ()) }
    { local:gen-variable('TargetedContext', 'TargetedContexts', ()) }
    { local:gen-case-impact('VectorsImpact', 'Vectors') }
    { local:gen-case-impact('IdeasImpact', 'Ideas') }
    { local:gen-case-impact('ResourcesImpact', 'Resources') }
    { local:gen-case-impact('PartnersImpact', 'Partners') }
    { local:gen-variable('CoachQ1', 'RatingScales', ()) }
    { local:gen-variable('CoachQ2', 'RatingScales', ()) }
    { local:gen-variable('CoachQ3', 'RatingScales', ()) }
    { local:gen-variable('CoachComAdvice1', 'CommunicationAdvices', ()) }
    { local:gen-variable('CoachComAdvice2', 'CommunicationAdvices', ()) }
  </Variables>
};

(: ======================================================================
   2016 version for Philipp Bubenzer (coachcom 2020) - Plugged October 2016
   ====================================================================== 
:)
declare function local:gen-variables() {
  <Variables>
    { local:gen-variable('Case-Status', 'Case', 'Name', 'WorkflowStatus', 'Status') }
    { local:gen-variable('Activity-Status', 'Activity', 'Name', 'WorkflowStatus', 'Status') }
    { local:gen-variable('Case-Topics', 'Topics', 'ShortName') }
    { local:gen-variable('SME-Size', 'Sizes', ()) }
    <!--
    <TargetedMarkets>{ string-join($enterprise//TargetedMarketRef/text(), $local:separator) }</TargetedMarkets>:)
    <DomainActivityRef>{ $enterprise/DomainActivityRef/text() }</DomainActivityRef>
    -->
    { local:gen-variable-regional-entities('Case-RegionalEntityRef', 'Acronym') }
    { local:gen-variable('NA-Tools', 'KnownTools', ()) }
    { local:gen-variable('NA-SectorGroup', 'SectorGroups', ()) }
    { local:gen-variable('NA-InitialContext', 'InitialContexts', ()) }
    { local:gen-variable('NA-TargetedContext', 'TargetedContexts', ()) }
    { local:gen-case-impact('NA-Vectors', 'Vectors') }
    { local:gen-case-impact('NA-Ideas', 'Ideas') }
    { local:gen-case-impact('NA-Resources', 'Resources') }
    { local:gen-case-impact('NA-Partners', 'Partners') }
    { local:gen-variable('Eval-CoachComAdvice', 'CommunicationAdvices', ()) }
    { local:gen-variable('Eval-KAMComAdvice', 'CommunicationAdvices', ()) }
    { local:gen-variable('Q', 'RatingScales', ()) }
    <!--
    { local:gen-variable('CoachQ1', 'RatingScales', ()) }
    { local:gen-variable('CoachQ2', 'RatingScales', ()) }
    { local:gen-variable('CoachQ3', 'RatingScales', ()) }
    -->
  </Variables>
};

let $cmd := request:get-attribute('oppidum.command')
let $target := tokenize($cmd/@trail, '/')[2]
let $call-phase := local:get-call($target)
let $call := $call-phase[1]
let $phase := $call-phase[2]
let $profile := access:get-current-person-profile()
return
  if (access:check-omniscient-user($profile)) then
    if (starts-with($call, 'Undef')) then
      <error>{ $call }</error>
    else
      local:gen-variables()
  else
    oppidum:throw-error('FORBIDDEN', ())
