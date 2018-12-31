xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Extension points generation for the formulars :
   - Investor self-registration
   - Berlin 2018 event regristration

   May 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
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
        concat($filter, $params, ";choice2_width1=300px;choice2_width2=300px;choice2_closeOnSelect=true"))
    else
      form:gen-cached-selector-for($tag, $lang, concat($filter, $params))
};

(: ======================================================================
   Generate selector for two level fields like domains of activity or markets
   TODO: move to form.xqm
   ====================================================================== 
:)
declare function local:gen-hierarchical-selector ($tag as xs:string, $xvalue as xs:string?, $optional as xs:boolean, $position as xs:string, $lang as xs:string ) {
  let $filter := if ($optional) then ' optional' else ()
  let $params := if ($xvalue) then
                  concat(';multiple=yes;xvalue=', $xvalue, ';typeahead=yes')
                 else
                  ';multiple=no'
  return
    if ($local:json-selectors) then
      custom:gen-cached-json-selector-for($tag, $lang,
        concat($filter, $params, ";choice2_width1=320px;choice2_width2=300px;choice2_closeOnSelect=true;choice2_position=", $position)) 
    else
      custom:gen-cached-selector-for($tag, $lang, concat($filter, $params))
};

(: ======================================================================
    Berlin 2018 workshop selectors
   ======================================================================
:)
declare function local:gen-workshops( $lang as xs:string, $noedit as xs:boolean ) {
  <site:field Key="questionWorkshop11s">
    { custom:gen-radio-selector-for('QuestionWorkshop11s',  $lang, $noedit, 'c-vertical-choice', ()) }
  </site:field>,
   <site:field Key="questionWorkshop21s">
     { custom:gen-radio-selector-for('QuestionWorkshop21s',  $lang, $noedit, 'c-vertical-choice', ()) }
  </site:field>,
  <site:field Key="questionWorkshop31s">
    { custom:gen-radio-selector-for('QuestionWorkshop31s',  $lang, $noedit, 'c-vertical-choice', ()) }
    </site:field>,
  <site:field Key="questionWorkshop41s">
    { custom:gen-radio-selector-for('QuestionWorkshop41s',  $lang, $noedit, 'c-vertical-choice', ()) }
  </site:field>
};

(: ======================================================================
    Berlin 2018 pitching sessions selectors
   ======================================================================
:)
declare function local:gen-pitching-sessions( $lang as xs:string, $noedit as xs:boolean ) {
  <site:field Key="pitching11">
    {
    custom:gen-radio-selector-for('PitchingSessions', $lang, $noedit, 'c-vertical-choice', 'PitchingSessionRef', (3,4,5,6,7,8,9))
    }
  </site:field>,
  <site:field Key="pitching12">
    {
    custom:gen-radio-selector-for('PitchingSessions', $lang, $noedit, 'c-vertical-choice', 'PitchingSessionRef', (1,2,5,6,7,8,9))
    }
  </site:field>,
  <site:field Key="pitching21">
    {
    custom:gen-radio-selector-for('PitchingSessions', $lang, $noedit, 'c-vertical-choice', 'PitchingSessionRef', (1,2,3,4,7,8,9))
    }
  </site:field>,
  <site:field Key="pitching22">
    {
    custom:gen-radio-selector-for('PitchingSessions', $lang, $noedit, 'c-vertical-choice', 'PitchingSessionRef', (1,2,3,4,5,6,9))
    }
  </site:field>
};

(: *** MAIN ENTRY POINT *** :)
let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $enterprise := request:get-parameter('enterprise', ())
let $result_cas := session:get-attribute('cas-res')
let $goal := request:get-parameter('goal', 'read')
return
  if ($goal = 'read') then
    if ($target = ('users-self-registration', 'investors-self-registration', 'berlin-beneficiary-registration', 'berlin-investor-registration')) then
      <site:view>
        { local:gen-workshops($lang, true()) }
        <site:field Prefix="yesno_">
          {
          custom:gen-radio-selector-for('YesNoScales', $lang, true(), 'c-inline-choice', ())
          }
        </site:field>
        <site:field Prefix="neworg_yesno">
          {
          custom:gen-radio-selector-for('YesNoScales', $lang, true(), 'c-inline-choice',  ())
          }
        </site:field>
        {
        if ($target = ('investors-self-registration', 'berlin-investor-registration')) then
          local:gen-pitching-sessions($lang, true())
        else (
          <site:field Key="clients">
            {
            custom:gen-radio-selector-for( 'Clients', $lang, true(), 'c-inline-choice', 'ClientRef', ())
            }
          </site:field>,
          <site:field Key="pitching">
            {
            custom:gen-radio-selector-for('PitchingSessions', $lang, true(), 'c-vertical-choice', (), (), '9', 'LongName')
            }
          </site:field>
          )
        }
        {
        if ($target = ('users-self-registration')) then 
        (
        <site:field Key="dearfirstname">
              <xt:use types="constant">
              {
                if(exists($result_cas)) then 
                  string($result_cas/*[local-name(.) ='firstname'])
                  else ()
              }
              </xt:use>
        </site:field>,
        <site:field Key="dearlastname">
              <xt:use types="constant">
              {
                if(exists($result_cas)) then 
                  string($result_cas/*[local-name(.) ='lastname'])
                  else ()
              }
              </xt:use>
        </site:field>,
         <site:field Key="ecasdomain">
          <xt:use types="input" param="filter=event">
              {
                if(exists($result_cas) and contains($result_cas/*[local-name(.) ='domain'],'eu.europa.ec')) then 
                   'yes'
                  else 
                   'no'
              }
          </xt:use> 
        </site:field>
        )
        else() 
        }
      </site:view>
     else
      <site:view/>

  else if ($target = ('users-self-registration','investors-self-registration', 'berlin-beneficiary-registration', 'berlin-investor-registration')) then 
    (: assumes update goal :)
    <site:view>
      <site:field Key="gender">
        <xt:use types="choice" values="Mr Mrs" i18n="Mr Mrs" param="filter=select2;select2_dropdownAutoWidth=true;select2_width=off;class=span12 a-control;multiple=no"/>
      </site:field>
      <site:field Prefix="corporate">
        {
        form:gen-selector-for('CorporateFunctions', $lang, " event;multiple=yes;xvalue=CorporateFunctionRef;typeahead=yes")
        }
      </site:field>
      <site:field Key="country">
        {
        form:gen-cached-selector-for('ISO3Countries', $lang, ";multiple=no;typeahead=yes")
        }
      </site:field>
      <site:field Key="investorTypes">
        {
        form:gen-selector-for('InvestorTypes', $lang, ";multiple=yes;xvalue=InvestorTypeRef;typeahead=yes")
        }
      </site:field>
      <site:field Key="organisation">
        {
        custom:gen-radio-selector-for('OrganisationAffiliations', $lang, false(), 'c-inline-choice', 'OrganisationAffiliationRef')
        }
      </site:field>
      <site:field Prefix="yesno_">
        {
        custom:gen-radio-selector-for('YesNoScales', $lang, false(), 'c-inline-choice', ())
        }
      </site:field>
      <site:field Prefix="neworg_yesno">
        {
        custom:gen-radio-selector-for('YesNoScales', $lang, false(), 'c-inline-choice',  (), (), '2', 'Name')
        }
      </site:field>
      <site:field Key="clients">
        {
        custom:gen-radio-selector-for( 'Clients', $lang, false(), 'c-inline-choice', 'ClientRef', ())
        }
      </site:field>
      
      {
      if ($target = ('investors-self-registration', 'users-self-registration')) then (: remove investors-self-registration when renamed:)
        (
        <site:field Key="dearfirstname">
              <xt:use types="constant" >
              {
                if(exists($result_cas)) then 
                  string($result_cas/*[local-name(.) ='firstname'])
                  else ()
              }
              </xt:use>
        </site:field>,
        <site:field Key="dearlastname">
              <xt:use types="constant" >
              {
                if(exists($result_cas)) then 
                  string($result_cas/*[local-name(.) ='lastname'])
                  else ()
              }
              </xt:use>
        </site:field>,
         <site:field Key="ecasdomain">
          <xt:use types="input" param="filter=event">
              {
                if(exists($result_cas) and contains($result_cas/*[local-name(.) ='domain'],'eu.europa.ec')) then (::)
                   'yes'
                  else ('no')
              }
          </xt:use> 
        </site:field>,
        <site:field Key="firstname">
              <xt:use types="input" param="filter=event">
              {
                if(exists($result_cas/*)) then 
                  string($result_cas/*[local-name(.) ='firstname'])
                  else()
              }
              </xt:use>
        </site:field>,
        <site:field Key="lastname">
              <xt:use types="input" param="filter=event">
              {
                if(exists($result_cas)) then 
                  string($result_cas/*[local-name(.) ='lastname'])
                  else ()
              }
              </xt:use>
        </site:field>,
        <site:field Key="member-email">
              <xt:use types="input">
              {
                let $email := string($result_cas/*[local-name(.) ='email'])
                return
                  if($email ne '') then (
                    attribute { 'param' } { 'filter=event' },
                    $email
                    )
                  else
                    attribute { 'param' } { 'filter=event;required=true' }
              }
              </xt:use>
        </site:field>,
        <site:field Key="enterprise">
          {
          custom:gen-enterprise-selector($lang, ";select2_width=360px;multiple=no;typeahead=yes")
          }
        </site:field>,
        <site:field Key="eiccompanyname">
          {
          custom:gen-filter-enterprise-selector($lang, ";select2_width=360px;multiple=yes;xvalue=EnterpriseRef;typeahead=yes",'Beneficiary')
          }
        </site:field>,
        
        <site:field Key="spokenlanguages">
          {
          form:gen-selector-for('SpokenLanguages', $lang, " event;multiple=yes;xvalue=SpokenLanguageRef;typeahead=yes")
          }
        </site:field>,
        <site:field Prefix="topics_">
          {
          custom:gen-selector3-for('ThematicsTopics', $lang, " optional;multiple=yes;xvalue=ThematicsTopicRef;typeahead=yes")
          }
        </site:field>,
        <site:field Key="size">
          {
          form:gen-cached-selector-for('Sizes', $lang, " optional;multiple=no;typeahead=yes;select2_minimumResultsForSearch=1")
          }
        </site:field>,
        <site:field Key="myorganisationtypes">
          {
          form:gen-selector-for('MyOrganisationsTypes', $lang, ";multiple=no;xvalue=MyOrganisationsTypeRef;typeahead=yes")
          }
        </site:field>,
        <site:field Key="invcorporganisationtypes">
          {
          custom:gen-radio-selector-for('InvestCorpoOrganisationsTypes', $lang, false(), 'c-inline-choice', 'InvestCorpoOrganisationsTypeRef')
          }
        </site:field>,
        <site:field Key="corpotypes">
          {
          form:gen-selector-for('CorporateTypes', $lang, " event;multiple=yes;xvalue=CorporateTypeRef;typeahead=yes")
          }
        </site:field>,
        <site:field Key="corpointerests">
          {
          form:gen-selector-for('CorporateInterests', $lang, " event;multiple=yes;xvalue=CorporateInterestRef;typeahead=yes")
          }
        </site:field>,
        
        <site:field Prefix="serviceproduct_">
          {
          (:form:gen-selector-for('DomainActivities', $lang, " optional;multiple=yes;xvalue=DomainActivityRef;typeahead=yes"):)
          local:gen-hierarchical-selector('DomainActivities', 'DomainActivityRef', true(), 'right', $lang)
          }
        </site:field>,
        <site:field Prefix="partner_">
          {
          form:gen-selector-for('PartnerTypes', $lang, " event;multiple=yes;xvalue=PartnerTypeRef;typeahead=yes")
          }
        </site:field>,
        <site:field Key="afforganisation">
          {
          custom:gen-radio-selector-for('OrganisationAffiliations', $lang, false(), 'c-inline-choice', 'OrganisationAffiliationRef')
          }
        </site:field>
        )
      else
        ()
      }
      <site:field Key="investmentInvestors">
        {
        form:gen-selector-for('InvestmentInvestors', $lang, ";multiple=yes;xvalue=InvestmentInvestorRef;typeahead=yes")
        }
      </site:field>
      <site:field Key="investmentInvestorTickets">
        {
        form:gen-selector-for('InvestmentInvestorTickets', $lang, ";multiple=yes;xvalue=InvestmentInvestorTicketRef;typeahead=yes")
        }
      </site:field>
      <site:field Key="targetedMarkets">
        {
        local:gen-hierarchical-selector("TargetedMarkets", "TargetedMarketRef", false(), $lang)
        }
      </site:field>
      <site:field Key="geonomenclature">
        {
        local:gen-hierarchical-selector("GeographicalMarkets", "GeographicalMarketRef", false(), $lang)
        }
      </site:field>
      {
      local:gen-workshops($lang, false()),
      if ($target = ('investors-self-registration', 'berlin-investor-registration')) then
        (
        local:gen-pitching-sessions($lang, false()),
        <site:field Key="acceleration">
          {
          (: FIXME: integrate default selection into custom:gen-radio-selector-for :)
          let $use := custom:gen-radio-selector-for('AccelerationServices', $lang, false(), 'c-vertical-choice', 'AccelerationServiceRef')
          return
            <xt:use types="choice" param="filter=event;appearance=full;multiple=yes;xvalue=AccelerationServiceRef;class=c-vertical-choice">{$use/@values,$use/@i18n }1</xt:use>
          }
        </site:field>
        )
      else (: implies berlin-beneficiary-registration or users-self-registration :)
        (
        <site:field Key="pitching">
          {
          custom:gen-radio-selector-for('PitchingSessions', $lang, true(), 'c-vertical-choice', (), (), '9', 'LongName')
          }
        </site:field>,
        <site:field Key="acceleration">
          {
          custom:gen-radio-selector-for('AccelerationServices', $lang, false(), 'c-vertical-choice',  'AccelerationServiceRef', (1, 4), '3', 'Name')
          }
        </site:field>,
        <site:field Key="acronym">
          {
          let $enterprise := if (not($enterprise)) then '1' else $enterprise  (: fallback for /forms :)
          return custom:gen-projects-acronym($enterprise, $lang, ";multiple=no;typeahead=yes")
          }
        </site:field>,
        <site:field Key="businessPartners">
          {
          form:gen-selector-for-filter('BusinessPartners', $lang, ";multiple=yes;xvalue=BusinessPartnerRef;typeahead=yes", '1')
          }
        </site:field>,
        <site:field Key="targetInvestments">
          {
          form:gen-selector-for('InvestmentInvestors', $lang, ";multiple=no;xvalue=InvestmentInvestorRef;typeahead=yes")
          }
        </site:field>,
        <site:field Key="targetInvestmentsTickets">
          {
          form:gen-selector-for('InvestmentInvestorTickets', $lang, ";multiple=no;xvalue=InvestmentInvestorTicketRef;typeahead=yes")
          }
        </site:field>,
        <site:field Key="hot-booth-slot">
          {
          form:gen-selector-for('HotBoothSlots', $lang, ";multiple=no;typeahead=yes")
          }
        </site:field>
        )
      }
    </site:view>

  else (: unlikely :)
    <site:view>
    </site:view>
