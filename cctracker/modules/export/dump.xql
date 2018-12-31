xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Database dump facility
   (while waiting for statistics availability)

   DEPRECATED : replaced with a new report (No 4) using the reporting 
   engine (as per SMEIMNT-278)

   November 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare variable $local:separator := ', '; (: use ; if CSV field separator is , in dump.xsl :)
declare variable $local:find-quote := '"';  (: use the same convention as quote in dump.xsl :)
declare variable $local:replace-quote := "'";  

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

declare function local:quotify( $item as element()? ) as xs:string? {
    replace(string($item), $local:find-quote, $local:replace-quote)
};

(: ======================================================================
   2015 version for Agnieska - unplugged October 2016
   ====================================================================== 
:)
declare function local:gen-sample-2015( $case as element(), $enterprise as element(), $activity as element()? ) as element() {
  let $needs := $activity/NeedsAnalysis
  return
    <Case>
      <PID>{ string($case/@ProjectId) }</PID>
      <Call>{ $case/Information/Call/Date/text() }</Call>
      <Acronym>{ $case/Information/Acronym/text() }</Acronym>
      <CaseNo>{ $case/No/text() }</CaseNo>
      <ActivityNo>{ if ($activity) then $activity/No/text() else '-1' }</ActivityNo>
      <CaseStatus>{ $case/StatusHistory/CurrentStatusRef/text() }</CaseStatus>
      <ActivityStatus>{ $activity/StatusHistory/CurrentStatusRef/text() }</ActivityStatus>
      <Topics>{ string-join($case/Information/Call/CallTopics/TopicRef/text(), $local:separator) }</Topics>
      <Country>{ $enterprise/Address/Country/text() }</Country>
      <Size>{ $enterprise/SizeRef/text() }</Size>
      <TargetedMarkets>{ string-join($enterprise//TargetedMarketRef/text(), $local:separator) }</TargetedMarkets>
      <DomainActivityRef>{ $enterprise/DomainActivityRef/text() }</DomainActivityRef>
      <RegionalEntityRef>{ $case/Information/ManagingEntity/RegionalEntityRef/text() }</RegionalEntityRef>
      <KAM>{ display:gen-name-person($case/Management/AccountManagerRef/text(), 'en') }</KAM>
      <Coach>{ display:gen-name-person($activity/Assignment/ResponsibleCoachRef/text(), 'en') }</Coach>
      <NeedsAnalysis>{ $needs/Analysis/Date/text() }</NeedsAnalysis>
      <Tools>{ string-join($needs//KnownToolRef/text(), $local:separator) }</Tools>
      <SectorGroup>{ $needs/Stats/SectorGroupRef/text() }</SectorGroup>
      <InitialContext>{ $needs/Context/InitialContextRef/text() }</InitialContext>
      <TargetedContext>{ $needs/Context/TargetedContextRef/text() }</TargetedContext>
      <VectorsImpact>{ string-join($needs/Impact//VectorRef/text(), $local:separator) }</VectorsImpact>
      <IdeasImpact>{ string-join($needs/Impact//IdeaRef/text(), $local:separator) }</IdeasImpact>
      <ResourcesImpact>{ string-join($needs/Impact//ResourceRef/text(), $local:separator) }</ResourcesImpact>
      <PartnersImpact>{ string-join($needs/Impact//PartnerRef/text(), $local:separator) }</PartnersImpact>
      <CoachQ1>{ $activity/FinalReport/KAMPreparation/RatingScaleRef/text() }</CoachQ1>
      <CoachQ2>{ $activity/FinalReport/ManagementTeam/RatingScaleRef/text() }</CoachQ2>
      <CoachQ3>{ $activity/FinalReport/ObjectivesAchievements/RatingScaleRef/text() }</CoachQ3>
      <CoachComAdvice1>{ $activity/FinalReport/Dissemination/RatingScaleRef/text() }</CoachComAdvice1>
      <CoachComAdvice2>{ $activity/FinalReport/Dissemination/CommunicationAdviceRef/text() }</CoachComAdvice2>
    </Case>
};

(: ======================================================================
   Helper function to extracts values of weight elements from an Activity 
   for a given root (identified by its first letter for optimization,
   'V' for Vectors, 'I' for 'Ideas' and so on...)
   Returns a comma separated list of "x#y" strings (e.g. '1#2; 5#3') where x
   is a code corresponding to a weight variable and y is the priority set on it
   NOTE: the string will be decoded client-side with Javascript for optimization
         (see uncompressWeights above)
   ====================================================================== 
:)
declare function local:extract-weight ( $weights as element()?, $root as xs:string, $value as xs:string ) as xs:string {
  string-join(
    for $v in $weights/*[starts-with(local-name(.), $root) and . = $value]
    return substring-after(local-name($v), '-'),
    $local:separator
    )
};

(: ======================================================================
   2016 version for Philipp Bubenzer (coachcom 2020) - Plugged October 2016
   ====================================================================== 
:)
declare function local:gen-sample( $case as element(), $enterprise as element(), $activity as element()? ) as element() {
  let $needs := $case/NeedsAnalysis
  let $archive := if ($needs/@LastModification ne $activity/NeedsAnalysis/@LastModification) then 
                    $activity/NeedsAnalysis
                  else
                    ()
  let $contact := $needs/ContactPerson
  return
    <Case>
      <!-- Case -->
      <Case-No>{ $case/No/text() }</Case-No>
      <Case-ProjectID>{ string($case/@ProjectId) }</Case-ProjectID>
      <Case-Acronym>{ $case/Information/Acronym/text() }</Case-Acronym>
      <Case-CallDate>{ $case/Information/Call/Date/text() }</Case-CallDate>
      <Case-CreationDate>{ $case/StatusHistory/Status[ValueRef eq '1']/Date/substring(text(), 1, 10) }</Case-CreationDate>
      <Case-Phase>{ $case/Information/Call/PhaseRef/text() }</Case-Phase>
      <Case-Topics>{ string-join($case/Information/Call/CallTopics/TopicRef/text(), $local:separator) }</Case-Topics>
      <Case-Status>{ $case/StatusHistory/CurrentStatusRef/text() }</Case-Status>
      <Case-RegionalEntityRef>{ $case/Information/ManagingEntity/RegionalEntityRef/text() }</Case-RegionalEntityRef>
      <Case-Summary>{ local:quotify($case/Information/Summary) }</Case-Summary>
      <Case-NeedsAnalysis>{ $needs/Analysis/Date/text() }</Case-NeedsAnalysis>
      <KAMID>{ $case/Management/AccountManagerRef/text() }</KAMID>
      <!-- Activity -->
      <Activity-No>{ if ($activity) then $activity/No/text() else '-1' }</Activity-No>
      <Activity-Service>{ $activity/Assignment/ServiceRef/text() }</Activity-Service>
      <CoachID>{ $activity/Assignment/ResponsibleCoachRef/text() }</CoachID>
      <Activity-Status>{ $activity/StatusHistory/CurrentStatusRef/text() }</Activity-Status>
      {
        for $status in fn:collection($globals:global-info-uri)//WorkflowStatus[@Name eq 'Activity']/Status
        let $ref := $status/Id
        return
          element { concat('AS-', $ref) } {
            $activity/StatusHistory/Status[ValueRef eq $ref]/Date/substring(text(), 1, 10)
          }
      }
      <!-- SME -->
      <SME-Name>{ $enterprise/Name/text() }</SME-Name>
      <SME-WebSite>{ $enterprise/WebSite/text() }</SME-WebSite>
      <SME-StreetNameAndNo>{ $enterprise/Address/StreetNameAndNo/text() }</SME-StreetNameAndNo>
      <SME-Town>{ $enterprise/Address/Town/text() }</SME-Town>
      <SME-PostalCode>{ $enterprise/Address/PostalCode/text() }</SME-PostalCode>
      <SME-Country>{ $enterprise/Address/Country/text() }</SME-Country>
      <SME-Creation>{ $enterprise/CreationYear/text() }</SME-Creation>
      <SME-Size>{ $enterprise/SizeRef/text() }</SME-Size>
      <SME-Markets>{ string-join($enterprise//TargetedMarketRef/text(), $local:separator) }</SME-Markets>
      <SME-Nace>{ $enterprise/DomainActivityRef/text() }</SME-Nace>
      <!-- SME Contact -->
      <CT-Sex>{ $contact/Sex/text() }</CT-Sex>
      <CT-Civility>{ $contact/Civility/text() }</CT-Civility>
      <CT-FirstName>{ $contact/Name/FirstName/text() }</CT-FirstName>
      <CT-LastName>{ $contact/Name/LastName/text() }</CT-LastName>
      <CT-Phone>{ $contact/Contacts/Phone/text() }</CT-Phone>
      <CT-Mobile>{ $contact/Contacts/Mobile/text() }</CT-Mobile>
      <CT-Email>{ $contact/Contacts/Email/text() }</CT-Email>
      <CT-Function>{ $contact/Function/text() }</CT-Function>
      <!-- Needs Analysis and Needs Analysis Archive  -->
      <NA-LastModif>{ substring($needs/@LastModification, 1, 10) }</NA-LastModif>
      <NAA-LastModif>{ substring($archive/@LastModification, 1, 10) }</NAA-LastModif>
      <NA-Tools>{ string-join($needs//KnownToolRef/text(), $local:separator) }</NA-Tools>
      <NAA-Tools>{ string-join($archive//KnownToolRef/text(), $local:separator) }</NAA-Tools>
      <NA-SectorGroup>{ $needs/Stats/SectorGroupRef/text() }</NA-SectorGroup>
      <NAA-SectorGroup>{ $archive/Stats/SectorGroupRef/text() }</NAA-SectorGroup>
      <NA-InitialContext>{ $needs/Context/InitialContextRef/text() }</NA-InitialContext>
      <NAA-InitialContext>{ $archive/Context/InitialContextRef/text() }</NAA-InitialContext>
      <NA-TargetedContext>{ $needs/Context/TargetedContextRef/text() }</NA-TargetedContext>
      <NAA-TargetedContext>{ $archive/Context/TargetedContextRef/text() }</NAA-TargetedContext>
      <NA-Vectors>{ string-join($needs/Impact//VectorRef/text(), $local:separator) }</NA-Vectors>
      <NAA-Vectors>{ string-join($archive/Impact//VectorRef/text(), $local:separator) }</NAA-Vectors>
      <NA-Ideas>{ string-join($needs/Impact//IdeaRef/text(), $local:separator) }</NA-Ideas>
      <NAA-Ideas>{ string-join($archive/Impact//IdeaRef/text(), $local:separator) }</NAA-Ideas>
      <NA-Resources>{ string-join($needs/Impact//ResourceRef/text(), $local:separator) }</NA-Resources>
      <NAA-Resources>{ string-join($archive/Impact//ResourceRef/text(), $local:separator) }</NAA-Resources>
      <NA-Partners>{ string-join($needs/Impact//PartnerRef/text(), $local:separator) }</NA-Partners>
      <NAA-Partners>{ string-join($archive/Impact//PartnerRef/text(), $local:separator) }</NAA-Partners>
      <NA-Context>{ local:quotify($needs/Context/Comments) }</NA-Context>
      <NAA-Context>{ local:quotify($archive/Context/Comments) }</NAA-Context>
      <NA-Challenges>{ local:quotify($needs/Comments) }</NA-Challenges>
      <NAA-Challenges>{ local:quotify($archive/Comments) }</NAA-Challenges>
      <NA-EvaluationMGT>{ local:quotify($activity/FinalReportApproval/Recognition/Comment) }</NA-EvaluationMGT>
      <NA-EvaluationTools>{ local:quotify($activity/FinalReportApproval/Tools/Comment) }</NA-EvaluationTools>
      <!-- Coaching -->
      {
      let $w := $activity/Assignment/Weights
      return (
        <Coach-Vectors-H>{ local:extract-weight($w, 'V', '3') }</Coach-Vectors-H>,
        <Coach-Vectors-M>{ local:extract-weight($w, 'V', '2') }</Coach-Vectors-M>,
        <Coach-Ideas-H>{ local:extract-weight($w, 'I', '3') }</Coach-Ideas-H>,
        <Coach-Ideas-M>{ local:extract-weight($w, 'I', '2') }</Coach-Ideas-M>,
        <Coach-Resources-H>{ local:extract-weight($w, 'R', '3') }</Coach-Resources-H>,
        <Coach-Resources-M>{ local:extract-weight($w, 'R', '2') }</Coach-Resources-M>,
        <Coach-Partners-H>{ local:extract-weight($w, 'P', '3') }</Coach-Partners-H>,
        <Coach-Partners-M>{ local:extract-weight($w, 'P', '2') }</Coach-Partners-M>
        )
      }
      <Coach-Objectives>{ local:quotify($activity/FundingRequest/Objectives) }</Coach-Objectives>
      <Coach-Activities>
        { 
          replace(
            string-join(
            for $d in $activity/FundingRequest//Task/Description[. ne '']
            return concat('# ', $d)
            , ' '
            ) 
            , $local:find-quote, $local:replace-quote
          )
        }
      </Coach-Activities>
      <!-- Evaluations -->
      <Eval-CoachComAdvice>{ $activity/FinalReport//CommunicationAdviceRef/text() }</Eval-CoachComAdvice>
      <Eval-KAMComAdvice>{ $activity/FinalReportApproval//CommunicationAdviceRef/text() }</Eval-KAMComAdvice>
      {
      let $fr := $activity/FinalReport
      let $fra := $activity/FinalReportApproval
      let $sme := $activity/Evaluation
      return 
        (
          <Q1>{ $fra/Recognition/RatingScaleRef/text() }</Q1>,
          <Q2>{ $fra/Tools/RatingScaleRef/text() }</Q2>,
          <Q3>{ $sme//RatingScaleRef[@For eq 'SME1']/text() }</Q3>,
          <Q4>{ $sme//RatingScaleRef[@For eq 'SME2']/text() }</Q4>,
          <Q5>{ $fra/Profiles/RatingScaleRef/text() }</Q5>,
          <Q6>{ $sme//RatingScaleRef[@For eq 'SME3']/text() }</Q6>,
          <Q7>{ $fr/KAMPreparation/RatingScaleRef/text() }</Q7>,
          <Q8>{ $fr/ManagementTeam/RatingScaleRef/text() }</Q8>,
          <Q9>{ $sme//RatingScaleRef[@For eq 'SME7']/text() }</Q9>,
          <Q10>{ $fr/Dissemination/RatingScaleRef/text() }</Q10>,
          <Q11>{ $sme//RatingScaleRef[@For eq 'SME4']/text() }</Q11>,
          <Q12>{ $fr/ObjectivesAchievements/RatingScaleRef/text() }</Q12>,
          <Q13>{ $sme//RatingScaleRef[@For eq 'SME5']/text() }</Q13>,
          <Q14>{ $sme//RatingScaleRef[@For eq 'SME6']/text() }</Q14>,
          <Q15>{ $fra/Dialogue/RatingScaleRef/text() }</Q15>
        )
      }
    </Case>
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
      <Cases Cases="{ count(collection($globals:cases-uri)/Case[Information/Call[Date eq $call][PhaseRef eq $phase]]) }"
        Activities="{ count(collection($globals:cases-uri)/Case[Information/Call[Date eq $call][PhaseRef eq $phase]]//Activity) }"
        Base="{ if (($target eq 'calls') and (not(ends-with($cmd/@exist-path, '/')))) then '..' else '../..' }" 
        User="{ misc:gen-current-person-name() }" Date="{ substring(string(current-dateTime()), 1, 19) }"
        Call="{ $call }" Phase=" { $phase }">
        {
        for $case in collection($globals:cases-uri)/Case[Information/Call[Date eq $call][PhaseRef eq $phase]]
        let $enterprise := $case/Information/ClientEnterprise
        order by $case/No
        return 
          if ($case//Activity) then
            for $activity in $case//Activity
            return
              local:gen-sample($case, $enterprise, $activity)
          else
            local:gen-sample($case, $enterprise, ())
        }
      </Cases>
  else
    oppidum:throw-error('FORBIDDEN', ())
