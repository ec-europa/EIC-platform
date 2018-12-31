Match module specification
==========================

By Stéphane Sire <s.sire@oppidoc.fr> - Updated: 2016-05-30

## Coach Match Suggestion

The suggestion algorithm can be invoked either from a Case Tracker or directly from a user's home page in Coach Match (Coach search tabs).

When invoked from a Case Tracker it uses a POST request on `/suggest`, the POST returns a model to construct the suggestion tunnel user interface (generated with *suggest.xql*), it also contains an XML data island with the search data which is used to repeat the search data.

When invoked directly from Coach Match user's home, the suggestion user interface is directly embedded into the user's home page (generated with *home.xql*).

In both cases the suggestion by itself is invoked by a POST request on `/suggest/fit` (search by fit) or eventually by a POST request on `/suggest/criteria` (search by criteria). 

The search results are returned as a JSON data structure.

The search restults are interpreted client-side in *cm-search.js* (resp. *cm-suggest.js*) to construct the search results table.


### Match module suggestion tunnel (called from Case Tracker)

When invoked from Case Tracker coach assignment Suggest Coaches button :

1. Case Tracker calls `POST /cases/xxx/activities/yyy` (activities/match.xql) with submitted data from #c-editor-coaching-assignment editor, this will prepare payload to invoke Coach Match (done in workflow.js)
2. Case Tracker calls `POST /suggest` on Coach Match (suggest/suggest.xql) with data copied from the previous response, this is an HTML post opening a new window (done in workflow.js)
3. [new window] upon loading Coach Match calls `POST /suggest/fit` (suggest/search-by-fit.xql, suggest/match.xqm) copying data from the XML content of the script #cm-sme-request element to retrieve suggested coaches (done in cm-suggest.js)
4. on every evaluation of a single coach calls Coach Match calls `POST /suggest/evaluation/X` copying data from the from the XML content of the script #cm-sme-request element to retrieve coach evaluation (done in cm-suggest.js)

The format to invoke Coach Match suggest tunnel is :

    <Match>
      <Acronym>Case Acronym to show somewhere in page title</Acronym>
      <CaseImpacts>
        <Rating_X_Y>Z</Rating_X_Y>
        ...
      </CaseImpacts>
      <Stats>
        <TargetedMarkets>
          <TargetedMarketRef>TM</TargetedMarketRef>
        </TargetedMarkets>
        <DomainActivityRef>DA</DomainActivityRef>
      </Stats>
      <Context>
        <InitialContextRef>LC</InitialContextRef>
        <TargetedContextRef>LC</TargetedContextRef>
      </Context>
      <ServiceRef>S</ServiceRef>
    </Match>

With :
  
    X  : 1 to 4
    Y  : 1 to x depending on X
    Z  : 1 to 3
    TM : Thomson Reuters second level code
    DA : Nace second level code
    LC : life cycle context code
    S  : service code
    
### Direct Search from Coach Match

In that case POST `/suggest/fit` with search data similar to :

    <Match>
      <CaseImpacts>
        <Rating_1_1>2</Rating_1_1>
        <Rating_2_10>3</Rating_2_10>
        <Rating_4_10>3</Rating_4_10>
        <Rating_4_1>2</Rating_4_1>
      </CaseImpacts>
      <Stats>
        <TargetedMarkets>
          <TargetedMarketRef>501010</TargetedMarketRef>
          <TargetedMarketRef>501020</TargetedMarketRef>
          <TargetedMarketRef>501030</TargetedMarketRef>
        </TargetedMarkets>
        <DomainActivityRef>J58</DomainActivityRef>
      </Stats>
      <Context>
        <InitialContextRef>1</InitialContextRef>
        <TargetedContextRef>3</TargetedContextRef>
      </Context>
      <ServiceRef>2</ServiceRef>
    </Match>

Web service API 
---------------

###External (called from case tracker)

- competence_fit( SME-Needs ) -> returns CoachSuggestions
- sme\_context_fit( SME-Needs ) -> returns CoachSuggestions
- performance_fit( CoachCriteria ) -> returns CoachSuggestions

- get\_coach\_competence_fit( SME-Needs ) -> returns CompetenceFit for coach
- get\_coach\_sme\_context_fit( SME_needs ) -> returns SME-ContextFit for coach

- store_performance( CoachMatchId, Performance ) 
- get\_coach( CoachMatchId ) -> returns Coach

###External and internal

- get\_coach_performances( CoachMatchId ) -> returns Performances for coach

####Internal

- create_coach( ) -> CoachMatchId
- import_coach( case tracker end point, CaseTrackerId ) -> CoachMatchId
- create_login( CoachMatchId ) -> Username

- edit_address( CoachMatchId, Profile )
- edit_experience( CoachMatchId, Skills )
- edit_competences( CoachMatchId, Skills )

Data types
----------

###Transitory (not saved)

    SME-Needs (input)

    CoachCriteria (input)

    CoachSuggestions (output)
      Coach*
        CoatchMatchId # coach match ID or case tracker ID ?
        Name (FirstName, LastName)
        Email

    Performance (input)

    CompetenceFit (output)

    SME-ContextFit (output)

    Coach evaluation summary for JSON conversion (output)

      <Coach>
        <Id>10</Id>
        <Competences>
          <Summary For="Competence fit indicators">
            <Average>XXX</Average>
            <Axis For="Business innovation vectors">
              <Score>85</Score>
            </Axis>
            <Axis For="Source of Internal Ideas">
              <Score>56</Score>
            </Axis>
            <Axis For="Internal resources">
              <Score>100</Score>
            </Axis>
            <Axis For="Partnerships">
              <Score>25</Score>
            </Axis>
          </Summary>
          <Details For="Business innovation vectors">
            <Skills For="Offering">
              <Fit>3</Fit>
            </Skills>
            <Skills For="Process">
              <Fit>3</Fit>
            </Skills>
            <Skills For="Distribution">
              <Fit>2</Fit>
            </Skills>
          </Details>
          <Details For="Sources of innovation ideas">
            <Skills For="Internal">
              <Fit>1</Fit>
            </Skills>
            <Skills For="Education and research">
              <Fit>2</Fit>
            </Skills>
          </Details>
       </Competences>
      </Coach>

###Persistent (saved)

    Persons
      Person*
        Id
        Information LastModification=""
        Knowledge LastModification=""
        Skills LastModification="" For="selector"
        Performances (feeds)
          Feed From="cc20-cctracker"
            Performance*

    Skills For="Services" (flat version)
      Skill For="1"
      ...

    Skills For="CaseImpacts" (double version)
      Skills For="Vectors"
        Skill For="1"
        ...
      Skills For="Vectors"
        Skill For="1"
        ...

    Skills For="TargetedMarkets" (double version)
      Skills For="5010"
        Skill For="501010"
        ...
      Skills For="Vectors"
        Skill For="1"
        ...

    Performances

Data implementation
-------------------

Single resource file per-person :

    /db/sites/ccmatch/persons/YYYY/MM/{NB}.xml

with faceted profile elements blocks : Information, Knowledge, Skills*

MANIFEST
--------

    formulars
      coach-contact     : Information 
      coach-experiences : Knowledge, Skills for LifeCycle, Nace, Markets, Services
      coach-competences : Skills for CaseImpacts
      sme-profile       : SME simulator (coach match tunnel testing)
      search-user       : users management 
      account           : login creation and update, password generation

    modules/sme
      form.xql : to simulate SME profile for search
      profile.xql : brings out the SME profile simulation editor

    modules/coaches
      data.xql : Read / Write coach faceted profile (XML level)
      home.xql : generate user's dashboard
      profile.xql : generate faceted profile editor
  
    modules/suggest
      match.xqm : matching algorithm
      evaluation.xql : handles request for individual coach evaluation against an SME profile (JSON)
      search-by-fit.xql : handles request for search by fit (competence or SME context) against an SME profile (JSON)
      suggest.xql : brings out coach match tunnel application
      suggest.xsl : extension for coach match application tunnel UI

Case Tracker Extensions
-----------------------

- get_coaches() -> returns Coaches
- get_performances( CaseTrackerId ) -> Performances
- subscribe\_coach( CaseTrackerId, CoachMatchId, 'Performance' feed, 'cc20-ccmatch', 'store_performance') : request to invove store\_performance of endpoint cc20-ccmatch to submit evaluation data each time one is received for the given coach

###User Interface

- Coach > "Import coach" button for EASME (creates profile, exports performances feed to cc20-ccmatch and subscribe it to performance feed)
- Coach > "Export coach" button for EASME to export a coach from Case Tracker to Coach Match and subscribe cc20-ccmatch to performance feed

For a coach it should be possible to see if s/he is linked with a coach in coach match from within the case tracker (which implies s/he is pushing Performance feed updates)

Notes : 

- "Import coach" tests 2 situations : a) the coach does not yet exists in case tracker or b) the coach already exists in the case tracker (same Email) in which case it should be linked instead of pure creation
- prévoir dans Coach match un bouton "Synch with case tracker" (compte le nombre de performances et si différent efface les performances dans Coach match et recharge depuis Case tracker)


