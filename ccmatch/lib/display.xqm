xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Functions to generate strings for display out of database content
   All generated strings are localized to the language passed as parameter

   September 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace display = "http://oppidoc.com/oppidum/display";
declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";

(: ======================================================================
   Returns a localized string for a given $lang and $key
   ======================================================================
:)
declare function display:get-local-string( $key as xs:string, $lang as xs:string ) as xs:string {
  let $res := fn:doc($globals:dico-uri)/site:Dictionary/site:Translations[@lang = $lang]/site:Translation[@key = $key]/text()
  return
    if ($res) then
      $res
    else
      concat('missing [', $key, ', lang="', $lang, '"]')
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
   Formats a dateTime for screen display
   Uses contextualized form if short is true()
   ======================================================================
:)
declare function display:gen-display-dateTime( $date as xs:string?, $lang as xs:string, $short as xs:boolean ) as xs:string {
  if ($date) then
    let $year := substring($date, 1, 4)
    return
      concat(
        substring($date ,9, 2), '/', substring($date, 6, 2), 
        if (not($short and starts-with(current-date(), $year))) then
          concat('/', $year)
        else
          (),
        ' at ',
        substring($date, 12, 2), ':', substring($date, 15, 2)
        )
  else
    ''
};

(: ======================================================================
   Formats a dateTime for screen display
   ======================================================================
:)
declare function display:gen-display-dateTime( $date as xs:string?, $lang as xs:string ) as xs:string {
  display:gen-display-dateTime($date, $lang, false())
};

(: ======================================================================
   Converts a reference to an option in a list into the option label
   NOTE: local namespace because it seems that if exported in display namespace 
   the function is shadowed by its synonym below with element()* signature
   ======================================================================
:)
declare function local:gen-name-for( $name as xs:string, $ref as xs:string?, $lang as xs:string ) as xs:string {
  if ($ref) then
    let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq $name]
    let $label := if (starts-with($defs/@Label, 'V+')) then substring-after($defs/@Label, 'V+') else string($defs/@Label)
    let $option := $defs//Option[*[local-name(.) eq string($defs/@Value)]/text() eq $ref]/*[local-name(.) eq $label]
    return
      if ($option) then
        if (contains($option, '::')) then (: satellite :)
          concat(substring-before($option, '::'), ' (', substring-after($option, '::'), ')')
        else
          $option
      else
        $ref
  else
    ''
};

(: ======================================================================
   Converts a list of references to options in a list into a list of option labels
   Note space after comma so that browsers cut long lists correctly
   ======================================================================
:)
declare function display:gen-list-for( $name as xs:string, $items as element()*, $lang as xs:string ) as xs:string {
  string-join(
    for $r in $items
    return local:gen-name-for($name, $r/text(), $lang),
    ', '
    )
};

declare function display:gen-name-for( $name as xs:string, $refs as element()*, $lang as xs:string ) as xs:string {
  if (count($refs) > 1) then
    display:gen-list-for($name, $refs, $lang)
  else
    local:gen-name-for($name, $refs/text(), 'en')
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
   Generates a person name (First name, Surname) from a reference to a person
   ======================================================================
:)
declare function display:gen-person-name-for-ref( $ref as xs:string?, $lang as xs:string ) {
  if ($ref) then
    let $p := fn:collection($globals:persons-uri)//Person[Id eq $ref]
    return
      if ($p) then
        if  (exists($p/Information/Name/FirstName) or exists($p/Information/Name/LastName)) then
          concat($p/Information/Name/FirstName, ' ', $p/Information/Name/LastName)
        else
          "Profile w/o name"
      else
        display:noref($ref, $lang)
  else 
    ""
};

declare function display:gen-person-name( $person as element()?, $lang as xs:string ) {
  if ($person) then
    if  (exists($person/Information/Name/FirstName) or exists($person/Information/Name/LastName)) then
      concat($person/Information/Name/LastName, ' ', $person/Information/Name/FirstName)
    else
      "Profile w/o name"
  else
    ""
};

(: ======================================================================
   Returns last update string for a log category in a person's record
   TODO: improve message (today, yesterday, etc)
   ======================================================================
:)
declare function display:gen-log-message-for($person as element(), $category as xs:string ) as xs:string {
  let $stamp := $person/Logs/Log[Category eq $category]/Date/text()
  return
    if ($stamp) then
      concat(
        'Last update : ',
        display:gen-display-date($stamp, 'en'),
        ' at ',
        substring($stamp, 12, 2), ':', substring($stamp, 15, 2)
        )
    else
      'Last update unknown'
};

declare function display:gen-all-log-message($person as element(), $number as xs:integer ) as element()* {
  let $slogs :=
    for $log in $person/Logs/Log[Category ne 'creation']
    let $stamp := $log/Date/text()
    order by $stamp descending
    return $log
  let $extra := (
    if (exists($person//Evaluation)) then
      <Log>
        <Date>{ max($person//Evaluation/xs:dateTime(@Date)) }</Date>
        <Category>custom</Category>
        <Label>Last evaluation</Label>
      </Log>
    else
      (),
    if (exists($person/Hosts/Host[@For = '1']/AccreditationRef)) then (: FIXME: hard-coded host :)
      let $last := $person/Hosts/Host[@For eq '1']/AccreditationRef[1]
      return
        <Log>
          <Date>{ string($last/@Date) }</Date>
          <Category>custom</Category>
          <Label>Acceptance set to { lower-case(display:gen-name-for('Acceptances', $last, 'en')) }</Label>
        </Log>
    else
      ()
    )
  return
    for $log in ($slogs[position() le $number], $person/Logs/Log[Category eq 'creation'], $extra)
    let $cat := $log/Category/text()
    let $stamp := $log/Date/text()
    order by $stamp descending
    return
      if ($cat eq 'creation') then
        <p>Creation : { display:gen-display-dateTime($stamp, 'en', true()) }</p>
      else if ($cat eq 'custom') then 
        <p>{ $log/Label/text() } : { display:gen-display-dateTime($stamp, 'en', true()) }</p>
      else
        <p>Last update in { $cat } : { display:gen-display-dateTime($stamp, 'en', true()) }</p>
};

(: ======================================================================
   Turns person availability status into a display string
   ====================================================================== 
:)
declare function display:gen-availability-message( $person as element() ) as item()* {
  if ($person/Preferences/NoCoaching) then (
    "Not available since ",
    display:gen-display-date($person/Preferences/NoCoaching/@Date, 'en')
    )
  else (: assumes Available :)
    ()
};
