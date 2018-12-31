xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

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

   November 2016 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace display = "http://oppidoc.com/oppidum/display";

declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../lib/globals.xqm";

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
    ''
};

(: ======================================================================
   Formats a date for screen display
   ======================================================================
:)
declare function display:gen-display-date-format( $date as xs:string?, $format as xs:string ) as xs:string {
  if ($date) then
    if($format = 'yyyy/mm/dd')then
       concat(substring($date,1,4), '/',substring($date,6,2), '/',substring($date,9,2) )
    else if($format = 'dd/mm/yyyy')then
       concat(substring($date,9,2), '/', substring($date,6,2), '/', substring($date,1,4))
    else
      concat(substring($date,9,2), '/', substring($date,6,2), '/', substring($date,1,4))
  else
    ''
};

(: ======================================================================
   Formats a date and time for screen display
   ======================================================================
:)
declare function display:gen-display-date-time( $date as xs:string? ) as xs:string {
  if ($date) then
    concat(
      substring($date,9,2), '/', substring($date,6,2), '/', substring($date,1,4),
      ' at ',
      substring($date,12,5)
      )
  else
    ''
};

(: ======================================================================
   Formats an interval date for screen display (FIXME)
   ======================================================================
:)
declare function display:gen-display-date-range( $date as xs:string+, $lang as xs:string ) as xs:string {
  if (count($date) = 2) then
    if ($date[1] eq $date[2]) then
      display:gen-display-date($date[1], 'en')
    else
      let $yl := substring($date[1],1,4)
      let $yr := substring($date[2],1,4)
      let $ml := substring($date[1],6,2)
      let $mr := substring($date[2],6,2)
      let $dl := substring($date[1],9,2)
      let $dr := substring($date[2],9,2)
      return
        if (($yl ne $yr) and ($ml ne $mr) and ($dl ne $dr)) then
          concat(display:gen-display-date($date[1], 'en'), ' - ', display:gen-display-date($date[2], 'en'))
        else if ($yl eq $yr) then
          concat(
          if (($ml eq $mr))  then
            concat(
            if ($dl eq $dr) then
              $dr
            else
              concat($dl, ' - ',$dr),
              '/', $mr
            )
          else
            concat($dl, '/', $ml, ' - ', $dr, '/', $mr),
          '/', $yr
          )
        else
          concat(
          if (($ml eq $mr))  then
            concat(
            if ($dl eq $dr) then
              $dr
            else
              concat($dl, ' - ',$dr),
              '/', $mr
            )
          else
            concat($dl, '/', $ml, ' - ', $dr, '/', $mr),
          '/', $yr
          )
  else
    ('')
};

(: ======================================================================
   Converts a reference to an option in a list into the option label
   Version with encoded value passed as string reference
   ======================================================================
:)
declare function display:gen-name-for-sref ( $name as xs:string, $ref as xs:string?, $lang as xs:string ) as xs:string+ {
  if ($ref) then
    let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
    let $option := ($defs//(Group|Option)[*[local-name(.) = ($defs/@Value,'Value')[1]]/text() eq $ref]/Name)[last()]
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
  string-join(
    for $r in $items
    return display:gen-name-for-sref($name, $r/text(), $lang),
    ', '
    )
};

(: ======================================================================
   Converts a list of references to a Selector to to a list of labels
   Note space after comma so that browsers cut long lists correctly
   ======================================================================
:)
declare function display:gen-name-for ( $name as xs:string, $refs as element()*, $lang as xs:string ) as xs:string {
  if (count($refs) > 1) then
    local:gen-list-for($name, $refs, $lang)
  else
    display:gen-name-for-sref($name, $refs/text(), $lang)
};

(: ======================================================================
   Return person name for an account $ref using first team member name
   (which is considered the most recent known name) with fallback 
   to master Information (e.g. unafiliated user)
   ======================================================================
:)
declare function display:gen-person-name-for-account( $ref as xs:string? ) {
  let $p := fn:head(fn:collection($globals:enterprises-uri)//Enterprise/Team//Member[PersonRef = $ref])
  return
    if ($p/Information) then
      concat($p/Information/Name/FirstName, ' ', $p/Information/Name/LastName)
    else
      let $fallback := fn:collection($globals:persons-uri)//Person[Id = $ref]
      return
        if ($p/Information) then
          concat($p/Information/Name/FirstName, ' ', $p/Information/Name/LastName)
        else
          ""
};

(: ======================================================================
   Generates a person name (Surname, First name) from a reference to an enterprise member
   ======================================================================
:)
declare function display:gen-name-member( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := fn:collection($globals:enterprises-uri)//Enterprise/Team//Member[PersonRef = $ref]
    return
      if ($p) then
        concat($p/Information/Name/LastName, ' ', $p/Information/Name/FirstName)
      else if ($ref eq 'import') then
        "case tracker importer"
      else if ($ref eq 'batch') then
        "case tracker batch"
      else
        display:noref( $ref, $lang )
  else
    ''
};

(: ======================================================================
   Generates a person name (Surname, First name) from a reference to an enterprise member
   ======================================================================
:)
declare function display:gen-member-name( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := fn:collection($globals:enterprises-uri)//Enterprise/Team//Member[PersonRef = $ref]
    return
      if ($p) then
        concat($p/Information/Name/FirstName, ' ', $p/Information/Name/LastName)
      else if ($ref eq 'import') then
        "case tracker importer"
      else if ($ref eq 'batch') then
        "case tracker batch"
      else
        display:noref( $ref, $lang )
  else
    ''
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
        concat($p/Information/Name/LastName, ' ', $p/Information/Name/FirstName)
      else if ($ref eq 'import') then
        "case tracker importer"
      else if ($ref eq 'batch') then
        "case tracker batch"
      else
        display:noref( $ref, $lang )
  else
    ''
};

(: ======================================================================
   Generates a person email from a reference to a person
   or a localized unknown reference message
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
   Converts a Roles model into a comma separated list of role names
   TODO: localize
   ======================================================================
:)
declare function display:gen-roles-for ( $roles as element()?, $lang as xs:string ) as xs:string? {
  if (exists($roles/Role)) then
    string-join(
      for $fref in $roles/Role/FunctionRef
      return
        globals:collection('global-info-uri')//Description[@Lang = $lang]/Selector[@Name eq 'Functions']/Option[Value eq $fref]/Brief,
      ', '
      )
  else
    '...'
};
