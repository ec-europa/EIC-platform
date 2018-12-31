xquery version "3.0";
(: --------------------------------------
   EIC Coaching application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Functions to generate strings for display out of database content
   All generated strings are localized to the language passed as parameter

   NOTE:
   - as (most of) these functions return strings to be inserted in text readonly
     input fields to show static views, we prefer to localize them directly
     instead of generating localization keys for post-render localization,
     generating keys would most probably imply to return an @i18n attribute
     and thus to be careful about invocation context

   OPTIMIZATION:
   - use a cache mechanism when possible if too slow

   July 2013 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace display = "http://oppidoc.com/oppidum/display";

declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";


(: ======================================================================
   Generates a memory cache using a map to speed up selectors decoding
   for persons profiles only
   ====================================================================== 
:)
declare function display:gen-map-for-roles( $role-ids as xs:string* ) as map() {
  map:new(
    for $r in $role-ids  
    let $defs := fn:collection('/db/sites/cctracker/persons')//Person[UserProfile//Role/FunctionRef eq $r]
    return
      if (exists($defs)) then
        map:entry(
          $r,
          map:new(
            for $opt in $defs
            return
              map:entry($opt/Id/text(), string-join($opt//Name/*, ' '))
          )
        )
      else
        ()
  )
};

(: ======================================================================
   Generates a memory cache using a map to speed up selectors decoding
   ====================================================================== 
:)
declare function display:gen-map-for( $selectors as xs:string*, $lang as xs:string ) as map() {
  map:new(
    for $name in $selectors
    let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
    return
      if (exists($defs)) then
        map:entry(
          $name,
          map:new(
            for $opt in $defs//Option
            return
              map:entry($opt/Value/text(), $opt/Name/text())
          )
        )
      else
        ()
  )
};

(: ======================================================================
   Variant using a supercharged element from the selector's definition
   ====================================================================== 
:)
declare function display:gen-map-for( $selectors as xs:string, $tag as xs:string, $lang as xs:string ) as map() {
  map:new(
    for $name in $selectors
    let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
    return
      if (exists($defs)) then
        map:entry(
          concat($name, $tag),
          map:new(
            for $opt in $defs//Option
            return
              map:entry($opt/Value/text(), $opt/*[local-name() eq $tag]/text())
          )
        )
      else
        ()
  )
};

(: ======================================================================
   Uses a cached version of selectors definitions to decode values
   The cache can be constructed once per request using display:gen-map-for
   ====================================================================== 
:)
declare function display:gen-map-name-for( $name as xs:string, $refs as element()*, $cache as map() ) {
  if (count($refs) > 1) then
    string-join(
      for $r in $refs
      return map:get(map:get($cache, $name), $r),
      ', '
    )
  else if (count($refs) eq 1) then
    map:get(map:get($cache, $name), $refs)
  else
    ''
};

(: ======================================================================
   Returns a hard coded string in case of an unkown reference
   FIXME:
   - read the string from the application thesaurus when available
   ======================================================================
:)
declare function display:noref( $ref as xs:string, $lang as xs:string ) as xs:string {
  concat("unknown reference (", $ref, ")")
};

(: ======================================================================
   Formats a date for screen display
   ======================================================================
:)
declare function display:gen-display-date( $date as xs:string?, $lang as xs:string ) as xs:string {
  if ($date) then
    concat(substring($date,9,2), '/', substring($date,6,2), '/', substring($date,1,4))
  else
    ('')
};

(: ======================================================================
   Converts a reference to a service to a service name
   ======================================================================
:)
declare function display:gen-service-name( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $r := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/Services/Service[Id = $ref]
    return
      if ($r) then
        $r/Name/text()
      else
        display:noref($ref, $lang)
  else
    "no service"
};

(: ======================================================================
   Generates a person name (First name, Surname) from a reference to a person
   ======================================================================
:)
declare function display:gen-person-name( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := fn:collection($globals:persons-uri)//Person[Id = $ref]
    return
      if ($p) then
        concat($p/Name/FirstName, ' ', $p/Name/LastName)
      else if ($ref eq 'import') then
        "case tracker importer"
      else if ($ref eq 'batch') then
        "case tracker batch"
      else
        display:noref($ref, $lang)
  else 
    ""
};

(: ======================================================================
   Generates a person name (Surname, First name) from a reference to a person
   ======================================================================
:)
declare function display:gen-name-person( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := fn:collection($globals:persons-uri)//Person[Id = $ref]
    return
      if ($p) then
        concat($p/Name/LastName, ' ', $p/Name/FirstName)
      else if ($ref eq 'import') then
        "case tracker importer"
      else if ($ref eq 'batch') then
        "case tracker batch"
      else
        display:noref($ref, $lang)
  else 
    ""
};

(: ======================================================================
   Generates a person email from a reference to a person 
   or a localized unknown reference message
   See also misc:gen-person-email
   ======================================================================
:)
declare function display:gen-person-email( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := fn:collection($globals:persons-uri)//Person[Id = $ref]
    return
      if ($p) then
        $p/Contacts/Email/text()
      else
        display:noref($ref, $lang)
  else 
    ""
};

(: ======================================================================
   Generates an enterprise name from a reference to an enterprise
   ======================================================================
:)
declare function display:gen-enterprise-name( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[Id = $ref]
    return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang)
  else
    ""
};

(: ======================================================================
   Converts a reference to an actvity status to an activity status name
   DEPRECATED
   ======================================================================
:)
declare function display:gen-activity-status-name( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $r := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/ActivityStatus/Status[Id = $ref]
    return
      if ($r) then
        $r/Name/text()
      else
        display:noref($ref, $lang)
  else
    ""
};

(: ======================================================================
   Converts a reference to an actvity types to an activity types name
   DEPRECATED
   ======================================================================
:)
declare function display:gen-activity-types-name( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $r := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/ActivityTypes/ActivityType[Id = $ref]
    return
      if ($r) then
        $r/Name/text()
      else
        display:noref($ref, $lang)
  else
    ""
};

(: ======================================================================
   Converts a list of references to CaseImpact values into a list of labels 
   with a given separator
   ======================================================================
:)
declare function display:gen-case-impact-name( $root as xs:string, $refs as xs:string*, $lang as xs:string, $separator as xs:string ) as xs:string {
  if (exists($refs)) then
    let $v := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/CaseImpact/Sections/Section[SectionRoot eq $root]
    return
      string-join(
        for $ref in $refs
        let $r := $v/SubSections/SubSection[Id = $ref]
        return
          if ($r) then
            $r/SubSectionName/text()
          else
            display:noref($ref, $lang),
        $separator
      )
  else
    ""
};

(: ======================================================================
   Generates phase name of an activity from a reference to the domain values - no translation needed: use of roman numbers
   ======================================================================
:)
declare function display:gen-activity-phase-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/ActivityPhases/Phase[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};		

(: ======================================================================
   Generates funding source name from a reference to the domain values 
   ======================================================================
:)
declare function display:gen-funding-source-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/FundingSources/FundingSource[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ======================================================================
   Generates market name from a reference to the domain values 
   ======================================================================
:)
declare function display:gen-target-market-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/Markets/MarketValue[string(Code) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ======================================================================
   Generates contact source name from a reference to the domain values 
   DEPRECATED
   ======================================================================
:)
declare function display:gen-contact-source-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/ContactSources/ContactSource[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ======================================================================
   Generates partner type name from a reference to the domain values 
   ======================================================================
:)
declare function display:gen-partnertype-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/PartnerTypes/PartnerType[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ======================================================================
   Generates partner role name from a reference to the domain values 
   ======================================================================
:)
declare function display:gen-partnerrole-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/PartnerRoles/PartnerRole[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ================================================================================
   Generates service responsible opinion name from a reference to the domain values 
   ================================================================================
:)
declare function display:gen-service-responsible-opinion-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/ServiceResponsibleOpinions/ServiceResponsibleOpinion[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ================================================================================
   Generates cantonal antenna opinion name from a reference to the domain values 
   ================================================================================
:)
declare function display:gen-cantonal-antenna-opinion-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/CantonalAntennaOpinions/CantonalAntennaOpinion[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ================================================================================
   Generates the name of an opinion about final report criteria from a reference to the domain values 
   ================================================================================
:)
declare function display:gen-final-report-opinion-name($ref as xs:string?, $lang) {
if ($ref) then
let $o := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/FinalReportOpinions/FinalReportOpinion[string(Id) = $ref]

return
      if ($o) then
        $o/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ================================================================================
   Generates decision making authority name from a reference to the domain values 
   ================================================================================
:)
declare function display:gen-decision-making-authority-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/DecisionMakingAuthorities/DecisionMakingAuthority[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};
(: ================================================================================
   Generates Funding Source name from a reference to the domain values 
   ================================================================================
:)
declare function display:gen-funding-source-name($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/FundingSources/FundingSource[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};
(: ================================================================================
   Generates communication advice text from a reference to the domain values 
   ================================================================================
:)
declare function display:gen-communication-advice-text($ref as xs:string?, $lang) {
if ($ref) then
let $p := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/CommunicationAdvices/CommunicationAdvice[string(Id) = $ref]

return
      if ($p) then
        $p/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ================================================================================
   Generates function name from a reference to the domain values 
   ================================================================================
:)
declare function display:gen-function-name($ref as xs:string?, $lang) {
if ($ref) then
let $f := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/Functions/Function[string(Id) = $ref]

return
      if ($f) then
        $f/Name/text()
      else
        display:noref($ref, $lang) 
  else
    "" 
};

(: ======================================================================
   Generates whitespace separated list of choices of final report section labels
   Escapes whitespaces for AXEL's 'choice' plugin syntax
   DEPRECATED
   ======================================================================
:)
declare function display:gen-reports-sections-selector($keys as xs:string*, $lang as xs:string) {
  string-join(
    for $k in $keys
    let $l := fn:doc($globals:dico-uri)/site:Dictionary/site:Translations[@lang = $lang]/site:Translation[@key = $k]/text()  
    return
      if ($l) then
        replace($l,' ','\\ ')
      else
        concat('Clef\ manquante\ [', $k, ']'),
    ' '
  )
};


(: ======================================================================
   Specific version for regional entities
   Converts a reference to an option in a list into the option label
   NOTE: local namespace because it seems that if exported in display namespace 
         the function is shadowed by its synonym below with element()* signature
   ======================================================================
:)
declare function local:gen-name-for-regional-entities ( $ref as xs:string?, $lang as xs:string ) as xs:string+ {
  if ($ref) then
    let $defs := <Selector Name="RegionalEntities" Value="Id" Label="Label" Test="EEN Entities">{fn:collection($globals:regions-uri)/Region}</Selector>
    let $label := if (starts-with($defs/@Label, 'V+')) then substring-after($defs/@Label, 'V+') else string($defs/@Label)
    let $option := $defs//Region[*[local-name(.) eq string($defs/@Value)]/text() eq $ref]/*[local-name(.) eq $label]
    return
      if ($option) then
        if (contains($option, '::')) then (: satellite :)
          concat(substring-before($option, '::'), ' (', substring-after($option, '::'), ')')
        else
          $option
          (: FIXME: concatenate with $ref when 'V+' as in forms.xqm
            if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/*[local-name(.) eq $label] :)
      else
        display:noref($ref, $lang)
  else
    ''
};

declare function local:gen-list-for-regional-entities ( $items as element()*, $lang as xs:string ) as xs:string {
  string-join(
    for $r in $items
    return local:gen-name-for-regional-entities($r/text(), $lang),
    ', '
    )
};

(: ======================================================================
   Specific version for regional entities
   Converts a list of references to a Selector to to a list of labels
   Note space after comma so that browsers cut long lists correctly
   ======================================================================
:)
declare function display:gen-name-for-regional-entities ( $refs as element()*, $lang as xs:string ) as xs:string {
  if (count($refs) > 1) then
    local:gen-list-for-regional-entities( $refs, $lang)
  else
    local:gen-name-for-regional-entities( $refs/text(), 'en')
};

(: ======================================================================
   Converts a reference to an option in a list into the option label
   NOTE: local namespace because it seems that if exported in display namespace 
         the function is shadowed by its synonym below with element()* signature
   ======================================================================
:)
declare function local:gen-name-for ( $name as xs:string, $ref as xs:string?, $lang as xs:string ) as xs:string+ {
  if ($ref) then
    let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
    let $label := if (starts-with($defs/@Label, 'V+')) then substring-after($defs/@Label, 'V+') else string($defs/@Label)
    let $option := ($defs//(Group|Option)[*[local-name(.) eq string($defs/@Value)]/text() eq $ref]/*[local-name(.) eq $label])[last()]
    return
      if ($option) then
        if (contains($option, '::')) then (: satellite :)
          concat(substring-before($option, '::'), ' (', substring-after($option, '::'), ')')
        else
          $option
          (: FIXME: concatenate with $ref when 'V+' as in forms.xqm
            if ($concat) then concat($v, ' ', $p/*[local-name(.) eq $label]) else $p/*[local-name(.) eq $label] :)
      else
        display:noref($ref, $lang)
  else
    ''
};

declare function local:gen-list-for ( $name as xs:string, $items as element()*, $lang as xs:string ) as xs:string {
  local:gen-list-for ( $name, $items, (), $lang)
};

declare function local:gen-list-for ( $name as xs:string, $items as element()*, $separator as xs:string?, $lang as xs:string ) as xs:string {
  string-join(
    for $r in $items
    return local:gen-name-for($name, $r/text(), $lang),
    if ($separator) then $separator else ', '
    )
};

(: ======================================================================
   Converts a list of references to a Selector to to a list of labels
   Note space after comma so that browsers cut long lists correctly
   ======================================================================
:)
declare function display:gen-name-for ( $name as xs:string, $refs as element()*, $lang as xs:string ) as xs:string {
  display:gen-name-for( $name, $refs, (), $lang ) 
};

declare function display:gen-name-for ( $name as xs:string, $refs as element()*, $separator as xs:string?, $lang as xs:string ) as xs:string {
  if (count($refs) > 1) then
    local:gen-list-for($name, $refs, if ($separator) then $separator else (), $lang)
  else
    local:gen-name-for($name, $refs/text(), $lang)
};

(: ======================================================================
   Short optimized version to generate Brief name when available 
   with fallback on Name
   Limited to single value string decoding to be fast
   Useful in reports or exports
   ====================================================================== 
:)
declare function display:gen-brief-for ( $name as xs:string, $ref as xs:string? ) as xs:string {
  if ($ref) then
    let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq $name]
    let $code-tag := string($defs/@Value) (: ideally Code but for legacy we keep indirection... :)
    let $option := ($defs//(Group|Option)[*[local-name(.) eq $code-tag] eq $ref])[last()]
    return
      if ($option) then
        fn:head(($option/Brief, $option/Name))
      else
        display:noref($ref, 'en')
  else
    ''
};

(: ======================================================================
   Returns a workflow status name for a given status
   ======================================================================
:)
declare function display:gen-workflow-status-name( $type as xs:string, $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $r := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = $lang]/WorkflowStatus[@Name = $type]/Status[Id = $ref]
    return
      if ($r) then
        $r/Name/text()
      else
        display:noref($ref, $lang)
  else
    ""
};

(: ======================================================================
   Returns a synthetic Activity title to display in Dashboard search result list
   ======================================================================
:)
declare function display:gen-activity-title( $case as element(), $activity as element(), $lang as xs:string ) as xs:string {
  let $service := display:gen-name-for('Services', $activity/Assignment/ServiceRef, $lang)
  let $year := substring($activity/CreationDate/text(), 1, 4)
  return  
    concat(if ($service) then $service else 'service pending...', ' - ', $year)
};

(: ======================================================================
   Returns a comma separated list of regional manager refs for the given 
   region or "NO KAM Coordinator for region NAME" or the empty string
   ======================================================================
:)
declare function display:gen-region-manager-names ( $ref as element()?, $lang as xs:string ) as xs:string? {
  if ($ref) then 
    let $coords := fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[FunctionRef[. eq '3']][RegionalEntityRef eq $ref]]/Id
    return
      if (count($coords) > 0) then
        string-join(
          for $c in $coords return display:gen-person-name($c, $lang),
          ', ')
      else
        concat('No KAM Coordinator for ', display:gen-name-for-regional-entities( $ref, $lang)) 
  else
    ''
};

(: ======================================================================
   Returns a comma separated list of regional manager (Surname, First name)'s for the given 
   region or "NO KAM Coordinator for region NAME" or the empty string
   ======================================================================
:)
declare function display:gen-names-region-manager ( $ref as element()?, $lang as xs:string ) as xs:string? {
  if ($ref) then 
    let $coords := fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[FunctionRef[. eq '3']][RegionalEntityRef eq $ref]]/Id
    return
      if (count($coords) > 0) then
        string-join(
          for $c in $coords return display:gen-name-person($c, $lang),
          ', ')
      else
        concat('No KAM Coordinator for ', display:gen-name-for-regional-entities( $ref, $lang)) 
  else
    ''
};

(: ======================================================================
   Converts a Roles model into a comma separated list of role names
   TODO: localize
   ======================================================================
:)
declare function display:gen-roles-for ( $roles as element()?, $lang as xs:string ) as xs:string? {
  if (exists($roles/Role)) then
    string-join(
      for $fref in $roles/Role/FunctionRef
      return fn:doc($globals:global-information-uri)//Function/Brief[../Id = $fref],
      ', '
      )
  else
    '...'
};

(: ======================================================================
   Return string to append parenthsized Call date from a project or empty
   Apply Call data type conventions (pluralization, etc.)
   ====================================================================== 
:)
declare function display:gen-call-date( $project as element()? ) as xs:string? {
  let $call-tag-ref := $project/Information/Call/*[ends-with(local-name(.), 'CallRef')]
  return
    if ($call-tag-ref) then
      let $call-name := concat(substring-before(local-name($call-tag-ref), 'CallRef'), 'Calls')
      return
        concat(' (', display:gen-name-for($call-name, $call-tag-ref, 'en'), ')')
    else
      ()
};

