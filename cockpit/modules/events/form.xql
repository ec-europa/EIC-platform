xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Enterprise formulars

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

(: flags for hierarchical 2 levels selectors:)
declare variable $local:json-selectors := true();

(: ======================================================================
   Generate selector for two level fields like domains of activity or markets
   TODO: move to form.xqm
   ====================================================================== 
:)
declare function local:gen-hierarchical-selector ($tag as xs:string, $xvalue as xs:string?, $optional as xs:boolean, $lang as xs:string ) {
  let $filter := if ($optional) then ' optional' else ()
  let $params := if ($xvalue) then
                  concat(';multiple=yes;xvalue=', $xvalue, ';typeahead=yes')
                 else
                  ';multiple=no'
  return
    if ($local:json-selectors) then
      custom:gen-cached-json-selector-for($tag, $lang,
        concat($filter, $params, ";choice2_width1=280px;choice2_width2=400px;choice2_closeOnSelect=true;choice2_position=left")) 
    else
      custom:gen-cached-selector-for($tag, $lang, concat($filter, $params))
};

(: ======================================================================
   Generates all selectors for all satisfaction formulars
   Factorization makes code easier to maintain
   Set $readonly to true() for 'read' version, false() otherwise
   ====================================================================== 
:)
declare function local:gen-satisfaction-fields( $readonly as xs:boolean, $lang as xs:string ) as element()* {
  <site:field Prefix="yesno_">
    { custom:gen-radio-selector-for('YesNoScales', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="fair_satisfaction">
    { custom:gen-radio-selector-for('FairSatisfactionLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
   <site:field Prefix="true_satisfaction">
    { custom:gen-radio-selector-for('TrueSatisfactionLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="satisfaction">
    { custom:gen-radio-selector-for('SatisfactionLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="min_satisfaction">
    { custom:gen-radio-selector-for('SatisfactionLevels', $lang, $readonly, 'c-inline-choice', (), '5') }
  </site:field>,
  <site:field Prefix="trade-fair-activities">
    { custom:gen-radio-selector-for('TradeFairActivities', $lang, $readonly, 'c-inline-choice', 'TradeFairActivityRef') }
  </site:field>,
  <site:field Prefix="trade-fair-services">
    { custom:gen-radio-selector-for('TradeFairServices', $lang, $readonly, 'c-inline-choice', 'TradeFairServiceRef') }
  </site:field>,
  <site:field Prefix="business-meeting-goals">
    { custom:gen-radio-selector-for('BusinessMeetingGoals', $lang, $readonly, 'c-vertical-choice', 'BusinessMeetingGoalRef') }
  </site:field>,
  <site:field Prefix="business-mission-values">
    { custom:gen-radio-selector-for('BusinessMissionValues', $lang, $readonly, 'c-vertical-choice', 'BusinessMissionValueRef') }
  </site:field>,
  <site:field Prefix="one-to-five">
    { custom:gen-radio-selector-for('OneToFiveScales', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="benefits">
    { custom:gen-radio-selector-for('EventBenefits', $lang, $readonly, 'c-inline-choice', 'EventBenefitRef') }
  </site:field>,
  <site:field Prefix="eventsbenefits">
    { custom:gen-radio-selector-for('EventsBenefits', $lang, $readonly, 'c-inline-choice', 'EventsBenefitRef') }
  </site:field>,
  <site:field Prefix="recommendation">
    { custom:gen-radio-selector-for('RecommendationLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="recommended">
    { custom:gen-radio-selector-for('RecommendedLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="utility">
    { custom:gen-radio-selector-for('UtilityLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="competency">
    { custom:gen-radio-selector-for('CompetencyLevels', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="yesnonop">
    { custom:gen-radio-selector-for('YesNoNopScales', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="rating">
    { custom:gen-radio-selector-for('RatingScales', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>
};

declare function local:gen-confirmation-fields( $readonly as xs:boolean, $lang as xs:string ) as element()* {
  <site:field Prefix="yesno_">
    { custom:gen-radio-selector-for('YesNoScales', $lang, $readonly, 'c-inline-choice', ()) }
  </site:field>,
  <site:field Prefix="business-meeting-goals">
    { custom:gen-radio-selector-for('BusinessMeetingGoals', $lang, $readonly, 'span c-vertical-choice', 'BusinessMeetingGoalRef') }
  </site:field>
};

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
let $enterprise := request:get-parameter('enterprise', ())
let $event := request:get-parameter('event', ())
return
  if ($goal = 'read') then
    <site:view>
      {
      if ($target eq 'medica-smart-city') then (
        <site:field Key="program">
          { custom:gen-radio-selector-for('MSCIEProgramParts', $lang, true(), 'c-inline-choice', 'MSCIEProgramPartRef') }
        </site:field>,
        <site:field Key="participants">
          { custom:gen-radio-selector-for('MSCIEParticipants', $lang, true(), 'c-inline-choice', 'MSCIEParticipantRef') }
        </site:field>,
        <site:field Key="partners">
          { custom:gen-radio-selector-for('MSCIEPartners', $lang, true(), 'c-vertical-choice', 'MSCIEPartnerRef') }
        </site:field>
        )

      else if ($target = ('corporate-abb')) then
        <site:field Key="partners">
          { custom:gen-radio-selector-for('MSCIEPartners', $lang, true(), 'c-vertical-choice', 'MSCIEPartnerRef') }
        </site:field>
        
      else if ($target = ('confirmation')) then
        (
        local:gen-confirmation-fields(true(), $lang),
        let $file := custom:gen-thumbnails-for-event( $enterprise, $event, 'Logo')[1]
        return
          <site:field Key="droplogo">
            <xt:use param="constant_media=image;image_base={$cmd/@base-url}enterprises/{$enterprise}/binaries/;noimage={$cmd/@base-url}static/cockpit/images/identity.png;class=img-polaroid" label="Logo" types="constant">{ $file }</xt:use>
          </site:field>,
        let $photos := custom:gen-thumbnails-for-event( $enterprise, $event, 'Photo')
        return
          for $p at $i in $photos 
          return
            <site:field Key="photo{$i}">
              <xt:use param="constant_media=image;image_base={$cmd/@base-url}enterprises/{$enterprise}/binaries/;noimage={$cmd/@base-url}static/cockpit/images/identity.png;class=img-polaroid" label="Photo{$i}" types="constant">{ $p }</xt:use>
            </site:field>
        )
        
      else if ($target = ('satisfaction', 'satisfaction-v2', 'investor')) then
        local:gen-satisfaction-fields(true(), $lang)

      else if (tokenize($cmd/@trail, '/')[2] ne 'pitching' and $target = ('impact')) then (
        <site:field Prefix="yesno_">
          { custom:gen-radio-selector-for('YesNoScales', $lang, true(), 'c-inline-choice', ()) }
        </site:field>,
        <site:field Prefix="yesnona_">
          { custom:gen-radio-selector-for('YesNoNAScales', $lang, true(), 'c-inline-choice', ()) }
        </site:field>,
        <site:field Prefix="business-agreements">
          { custom:gen-radio-selector-for('BusinessAgreementTypes', $lang, true(), 'c-inline-choice', 'BusinessAgreementTypeRef') }
        </site:field>,
        <site:field Prefix="market-adaptations">
          { custom:gen-radio-selector-for('MarketAdaptationTypes', $lang, true(), 'c-inline-choice', 'MarketAdaptationTypeRef') }
        </site:field>
        )
        
      else if ($target = ('impact')) then (
        <site:field Prefix="yesno_">
          { custom:gen-radio-selector-for('YesNoScales', $lang, true(), 'c-inline-choice', ()) }
        </site:field>,
        <site:field Prefix="business-agreements">
          { custom:gen-radio-selector-for('BusinessAgreementTypes', $lang, true(), 'c-inline-choice', 'BusinessAgreementTypeRef') }
        </site:field>,
         <site:field Prefix="strategy">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="organisations">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="market_entries">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="partnership">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="finance">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="turnover">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="employments">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>
        )
      
      else
        ()
      }
    </site:view>
  else
    if (tokenize($cmd/@trail, '/')[2] eq 'pitching' and $target = ('impact')) then
      <site:view>
        <site:field Prefix="yesno_">
          { custom:gen-radio-selector-for('YesNoScales', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
        <site:field Prefix="business-agreements">
          { custom:gen-radio-selector-for('BusinessAgreementTypes', $lang, false(), 'c-inline-choice', 'BusinessAgreementTypeRef') }
        </site:field>,
         <site:field Prefix="strategy">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="organisations">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="market_entries">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="partnership">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="finance">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="turnover">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>,
         <site:field Prefix="employments">
          { custom:gen-radio-selector-for('RecommendedLevels', $lang, false(), 'c-inline-choice', ()) }
        </site:field>
      </site:view>
    else if ((tokenize($cmd/@trail, '/')[2] = ('otf', 'investors', 'feedback', 'easme')) or ($target = ('academy', 'satisfaction', 'satisfaction-v2'))) then
      if ($target eq 'confirmation') then
        <site:view>
          { local:gen-confirmation-fields(false(), $lang) }
          <site:field Key="country">
            { form:gen-cached-selector-for('Countries', $lang, ";multiple=no;typeahead=yes") }
          </site:field>
          <site:field Key="droplogo">
            <xt:use types="drop" label="DropLogo" param="id=droplogo;url_post={$cmd/@base-url}enterprises/{$enterprise}/binaries/{$event}/logo;url_get={$cmd/@base-url}enterprises/{$enterprise}/binaries/list.xml?event={$event}&amp;type=logo;number=1;xvalue=ResourceId;file_size_limit=1.5;file_type=image/jpeg,image/png,image/tiff"/>
          </site:field>
          <site:field Key="dropphoto">
            <xt:use types="drop" label="DropPhotos" param="id=dropphoto;url_post={$cmd/@base-url}enterprises/{$enterprise}/binaries/{$event}/photo;url_get={$cmd/@base-url}enterprises/{$enterprise}/binaries/list.xml?event={$event}&amp;type=photo;number=3;xvalue=ResourceId;file_size_limit=3;file_type=image/jpeg,image/png,image/tiff"/>
          </site:field>
        </site:view>
        
      else if ($target = ('satisfaction', 'satisfaction-v2', 'investor')) then
        <site:view>
          { local:gen-satisfaction-fields(false(), $lang)}
        </site:view>

      else if ($target eq 'impact') then
        <site:view>
          <site:field Prefix="yesno_">
            { custom:gen-radio-selector-for('YesNoScales', $lang, false(), 'c-inline-choice', ()) }
          </site:field>
          <site:field Prefix="yesnona_">
            { custom:gen-radio-selector-for('YesNoNAScales', $lang, false(), 'c-inline-choice', ()) }
          </site:field>
          <site:field Prefix="business-agreements">
            { custom:gen-radio-selector-for('BusinessAgreementTypes', $lang, false(), 'c-inline-choice', 'BusinessAgreementTypeRef') }
          </site:field>
          <site:field Prefix="market-adaptations">
            { custom:gen-radio-selector-for('MarketAdaptationTypes', $lang, false(), 'c-inline-choice', 'MarketAdaptationTypeRef') }
          </site:field>
        </site:view>
      else
        <site:view>
          <site:field Key="acronym">
            { 
            let $enterprise := if (not($enterprise)) then '1' else $enterprise  (: fallback for /forms :)
            return custom:gen-projects-acronym($enterprise, $lang, ";multiple=no;typeahead=yes")
            }
          </site:field>
          {
            if ($target = ('sme', 'medica-smart-city')) then
              let $sel := form:gen-selector-for('ApplicabilityRanks', $lang, " event;multiple=no;xvalue=ApplicabilityRankRef;select2_width=150px")
              return
                (
                if ($target eq 'medica-smart-city') then (
                  <site:field Key="program">
                    { 
                    (:form:gen-selector-for('MSCIEProgramParts', $lang, " event;multiple=yes;xvalue=MSCIEProgramPartRef"):)
                    custom:gen-radio-selector-for('MSCIEProgramParts', $lang, false(), 'c-inline-choice', 'MSCIEProgramPartRef') 
                    }
                  </site:field>,
                  <site:field Key="participants">
                    { 
                    (:form:gen-selector-for('MSCIEParticipants', $lang, ";multiple=yes;xvalue=MSCIEParticipantRef"):)
                    custom:gen-radio-selector-for('MSCIEParticipants', $lang, false(), 'c-inline-choice', 'MSCIEParticipantRef') 
                    }
                  </site:field>,
                  <site:field Key="partners">
                    { 
                    (:form:gen-selector-for('MSCIEPartners', $lang, " event;multiple=yes;xvalue=MSCIEPartnerRef"):)
                    custom:gen-radio-selector-for('MSCIEPartners', $lang, false(), 'c-vertical-choice', 'MSCIEPartnerRef') 
                    }
                  </site:field>
                  )
                else
                  (),
                <site:field Key="ebitda-app">
                  <xt:use>{$sel/(@*|*), tokenize($sel/@values,' ')[1]}</xt:use>
                </site:field>,
                <site:field Key="revenue-app">
                  <xt:use>{$sel/(@*|*), tokenize($sel/@values,' ')[1]}</xt:use>
                </site:field>,
                <site:field Key="kind">
                  { form:gen-selector-for('InvestmentKinds', $lang, ";multiple=yes;xvalue=InvestmentKindRef") }
                </site:field>,
                <site:field Key="size">
                  { form:gen-selector-for('InvestmentSizes', $lang, ";multiple=no;xvalue=InvestmentSizeRef") }
                </site:field>,
                <site:field Key="share">
                  { form:gen-selector-for('SellingShares', $lang, ";multiple=no;xvalue=SellingShareRef") }
                </site:field>,
                <site:field Key="who">
                  { form:gen-selector-for('InvestorKinds', $lang, ";multiple=yes;xvalue=InvestorKindRef") }
                </site:field>
                )
            else if ($target eq 'academy') then
              let $sel := form:gen-selector-for('YesNoScales', $lang, " event;multiple=no;select2_width=150px")
              return
                <site:field Key="coach-att">
                  <xt:use>{$sel/(@*|*), tokenize($sel/@values,' ')[1]}</xt:use>
                </site:field>
            else if ($target = ('corporate-abb')) then
              <site:field Key="partners">
                { 
                custom:gen-radio-selector-for('MSCIEPartners', $lang, false(), 'c-vertical-choice', 'MSCIEPartnerRef') 
                }
              </site:field>

            else if ($target = ('coordinator-day')) then
              <site:field Key="nationality">
                { form:gen-cached-selector-for('ISO3Countries', $lang, ";multiple=no;typeahead=yes") }
              </site:field>

            else
              ()
          }
        </site:view>
    else if ($target eq 'search') then
      <site:view>
        <site:field Key="programs">
          { custom:gen-cached-selector-for('FundingPrograms', $lang, ";multiple=yes;xvalue=FundingProgramRef;typeahead=no") }
        </site:field>
        <site:field Key="acronyms">
          { custom:gen-all-projects-acronym('en', ';multiple=yes;xvalue=Acronym;typehead=yes') }
        </site:field>
        <site:field Key="terminations">
          { custom:gen-cached-selector-for('TerminationFlags', $lang, ";multiple=yes;xvalue=TerminationFlagRef;typeahead=no") }
        </site:field>
        <site:field Key="validity">
          { custom:gen-cached-selector-for('StatusFlags', $lang, ";multiple=yes;xvalue=StatusFlagRef;typeahead=no") }
        </site:field>
        <site:field Key="company-type">
          { form:gen-cached-selector-for('CompanyTypes', $lang, ";multiple=yes;xvalue=CompanyTypeRef;typeahead=yes") }
        </site:field>
        <site:field Key="enterprises">
          { custom:gen-enterprise-selector($lang, ";multiple=yes;xvalue=EnterpriseRef;typeahead=yes") }
        </site:field>
        <site:field Key="category">
          { custom:gen-json-selector-for( custom:gen-nested-selector-for-events(), $lang, "multiple=yes;xvalue=EventRef;choice2_closeOnSelect=true;placeholder=All;choice2_width1=150px;choice2_width2=400px")}
        </site:field>
        <site:field Key="PO">
          { custom:gen-po-selector(";multiple=yes;xvalue=ProjectOfficerRef;typeahead=yes", 'span') }
        </site:field>
      <site:field Key="towns">
        { custom:gen-town-selector($lang, ";multiple=yes;xvalue=Town;typeahead=yes") }
      </site:field>
        <site:field Key="country">
          { form:gen-cached-selector-for('Countries', $lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
        </site:field>
      <site:field Key="sizes">
        { form:gen-cached-selector-for('Sizes', $lang, ";multiple=yes;xvalue=SizeRef;typeahead=yes;select2_minimumResultsForSearch=1") }
      </site:field>
      <site:field Key="domains-of-activities">
        { local:gen-hierarchical-selector('DomainActivities', 'DomainActivityRef', false(), $lang) }
      </site:field>
      <site:field Key="targeted-markets">
        { local:gen-hierarchical-selector('TargetedMarkets', 'TargetedMarketRef', false(), $lang) }
      </site:field>
        <site:field Key="status">
          { form:gen-selector-for('OTF', $lang, " event;multiple=yes;xvalue=StatusRef;typeahead=yes")}
        </site:field>
      </site:view>
    else
      <site:view/>
      
