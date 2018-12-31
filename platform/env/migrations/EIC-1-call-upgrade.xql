xquery version "1.0";

let $cases := collection('/db/sites/cctracker/cases')
return
  <Res>{
  for $c in $cases//Case[not(Information/Call/FundingProgramRef)]
  let $call := $c/Information/Call
  let $type :=  if ($call/PhaseRef/text() eq '1') then '1-1' else '1-2'
  let $new :=
    <Call>
       <FundingProgramRef>1</FundingProgramRef>
       <SMEiFundingRef>{ $type }</SMEiFundingRef>
       <SMEiCallRef>
       { 
       let $date := concat(substring($call/Date,9,2), '/', substring($call/Date,6,2), '/',substring($call/Date,1,4))
       return collection('/db/sites/cctracker/global-information')//Selector[@Name eq 'SMEiCalls']//Code[../Name eq $date][ancestor::Group/Type eq $type]/text()
       }
       </SMEiCallRef>
       { $call/(CallTopics | EICPanels) }
    </Call>
  return
    if (
      (($call/PhaseRef/text() eq '1' and $new/SMEiFundingRef eq '1-1') or
       ($call/PhaseRef/text() eq '2' and $new/SMEiFundingRef eq '1-2')) and $new/SMEiCallRef ne '') then
    update replace $call with $new
    else
      <Failed>{ $c/No, $call, $new }</Failed>
}</Res>
