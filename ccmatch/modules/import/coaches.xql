xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utility to batch import persons

   TODO: 
   - do not generate Address when Country missing or not decoded
   - do not generate Knowledge when EU-Languages missing and no CV-Lin
   - do not generate empty <Skills> blocks


   October 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:input := '/db/batch/coaches-2015-10-19.xml';
declare variable $local:role := '4'; (: coach :)

declare function local:canonize( $name as xs:string ) {
  lower-case(replace($name, "[ _&amp;,\.]", ""))
};

declare function local:get-matching-element( $option as element(), $row as element() ) as element()* {
  let $res := 
    if ($option/Name/@ImportKey) then 
      let $key := string($option/Name/@ImportKey) (:key match:)
      return
        if ($key eq '-') then (: higher level that cannot be sorted into the lower more differentiated level :)
          ()
        else if ($key eq '^') then (:full match:)
          $row/*[lower-case(local-name(.)) eq lower-case($option/Name/text())]
        else (:prefix match:)
          $row/*[starts-with(local:canonize(local-name(.)), $key)]
    else
      let $key := local:canonize($option/Name)
      return
        $row/*[local:canonize(local-name(.)) eq $key]
  return (: handles case of columns with same name :)
    if ($option/Name/@ImportIndex) then
      $res[position() >= number($option/Name/@ImportIndex)]
    else
      $res
};

(: ======================================================================
   ====================================================================== 
:)
declare function local:gen-skill2-matrix-for ( $name as xs:string, $row as element()) as element() {
  <Skills For="{ $name }">
    {
    for $group in fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq $name]/Group
    return
      let $skills := 
        for $option in $group//Option
        let $match := local:get-matching-element($option, $row)
        return
          if (exists($match)) then
            if ($match[1] eq '') then
              ()
            else
              <Skill For="{ $option/Code }">
                { 
                  (:if ($match[2]) then
                    attribute { 'Comment' } { $match[2]/text() }
                  else
                    (),:)
                  if (number($match[1]/text()) = xs:double('NaN') or not(number($match[1]/text()) = (0,1,2))) then
                    1
                  else
                    number($match[1]/text()) + 1
                }
              </Skill>
          else if ($option/Name/@ImportKey eq '-') then
            () (:<SKIP Name="{ concat($name, ' : ', $option/Name) }"/>:)
          else 
            <MISSING Name="{ concat($name, ' : ', $option/Name) }"/>
      return
        if (exists($skills)) then
          <Skills For="{ $group/Code }">{ $skills }</Skills>
        else
          ()
    }
  </Skills>
};

(: ======================================================================
   Variant matching only Options with ImportKey
   Copy cat of local:gen-skill2-matrix-for with XPath filter in iterations
   (used for Nace since EU Survey limited to level 1)
   ====================================================================== 
:)
declare function local:gen-partial-skill-matrix-for ( $name as xs:string, $row as element()) as element() {
  <Skills For="{ $name }">
    {
    for $group in fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq $name]/Group[Selector/Option/Name/@ImportKey]
    return
      let $skills := 
        for $option in $group//Option[Name/@ImportKey]
        let $match := local:get-matching-element($option, $row)
        return
          if (exists($match)) then
            if ($match[1] eq '') then
              ()
            else
              <Skill For="{ $option/Code }">
                { 
                  (:if ($match[2]) then
                    attribute { 'Comment' } { $match[2]/text() }
                  else
                    (),:)
                  if (number($match[1]/text()) = xs:double('NaN') or not(number($match[1]/text()) = (0,1,2))) then
                    1
                  else
                    number($match[1]/text()) + 1
                }
              </Skill>
          else if ($option/Name/@ImportKey eq '-') then
            () (:<SKIP Name="{ concat($name, ' : ', $option/Name) }"/>:)
          else 
            <MISSING Name="{ concat($name, ' : ', $option/Name) }"/>
      return
        if (exists($skills)) then
          <Skills For="{ $group/Code }">{ $skills }</Skills>
        else
          ()
    }
  </Skills>
};

(: ======================================================================
   ====================================================================== 
:)
declare function local:gen-skill1-matrix-for ( $name as xs:string, $row as element() ) as element() {
  <Skills For="{ $name }">
    {
    for $option in fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq $name]/Option
    return
      let $match := local:get-matching-element($option, $row) 
      return
        if (exists($match)) then
          if ($match[1] eq '') then
            ()
          else
            <Skill For="{ $option/Id }">
              { 
                (:if ($match[2]) then
                  attribute { 'Comment' } { $match[2]/text() }
                else
                  (),:)
                if (number($match[1]/text()) = xs:double('NaN') or not(number($match[1]/text()) = (0,1,2))) then
                  1
                else
                  number($match[1]/text()) + 1
              }
            </Skill>
        else
          <MISSING Name="{ concat($name, ' : ', $option/Name) }"/> 
    }
  </Skills>
};

(: ======================================================================
   Converts an EC full Excel country name into a database Country code
   ======================================================================
:)
declare function local:gen-country-code-for( $country as xs:string?, $assert as xs:boolean ) {
  if ($country) then 
    let $option := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']//Selector[@Name eq 'Countries']/Option[lower-case(CountryName) eq lower-case($country)]
    return
      if ($option) then
        <Country>{ $option/CountryCode/text() }</Country>
      else if ($assert) then
        <MISSING Name="Country">{ $country }</MISSING>
      else
        ()
  else if ($assert) then
    <MISSING Name="Country">EMPTY</MISSING>
  else
    ()
};

(: ======================================================================
   Converts an EC full Excel languages semi-colon separated list into a database EU-Languages codes
   ======================================================================
:)
declare function local:gen-languages-code-for( $languages as xs:string?, $assert as xs:boolean ) {
  if ($languages) then 
    let $tokens := tokenize($languages, ';')
    let $options := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']//Selector[@Name eq 'EU-Languages']/Option[Name = $tokens]
    return
      if ($options) then
        <SpokenLanguages>
          {
          for $o in $options
          return <EU-LanguageRef>{ $o/Code/text() }</EU-LanguageRef>
          }
        </SpokenLanguages>
      else if ($assert) then
        <MISSING Name="EU-Language">{ $languages }</MISSING>
      else
        ()
  else if ($assert) then
    <MISSING Name="EU-Languages">EMPTY</MISSING>
  else
    ()
};

(: ======================================================================
   TODO: 
   - automatically generate $local:first index
   - automatically store into database
   ====================================================================== 
:)
declare function local:gen-person-with-role( $row as element(), $id as xs:string, $role-ref as xs:string ) as element() {
  let $assert := true()
  return
    <Person>
      <Id>{ $id }</Id>
      <UserProfile>
        <Roles>
          <Role>
            <FunctionRef>{ $role-ref }</FunctionRef>
          </Role>
        </Roles>
      </UserProfile>
      <Information>
        <Name>
          <LastName>{ $row/LastName/text() }</LastName>
          <FirstName>{ $row/FirstName/text() }</FirstName>
        </Name>
        <Contacts>
          { $row/Email }
        </Contacts>
        {
        if (($row/Country) or $assert) then 
          <Address>
            { local:gen-country-code-for( $row/Country/text(), true() ) }
          </Address>
        else
          ()
        }
      </Information>
      <Knowledge>
        {
        if ($row/CV/text() = ('NA', 'N/A') or $row/CV = '') then
          ()
        else
          <CV-Link>{ $row/CV/text() }</CV-Link>
        }
        { local:gen-languages-code-for( $row/Languages/text(), true() ) }
      </Knowledge>
      { local:gen-skill2-matrix-for('CaseImpacts', $row) }
      { local:gen-skill1-matrix-for('LifeCycleContexts', $row) }
      { local:gen-skill2-matrix-for('TargetedMarkets', $row) }
      { local:gen-partial-skill-matrix-for('DomainActivities', $row) }
      { local:gen-skill1-matrix-for('Services', $row) }
    </Person>
};

(: ======================================================================
   Recursive function to import max persons from rows
   NOTE: while resursing persons are created in database with the cur-key 
   index so you should be sure to execute that script while no one else can 
   create persons
   ====================================================================== 
:)

declare function local:import-iter( 
  $action as xs:string,
  $rows as element()*, 
  $max as xs:double, 
  $done as xs:double, 
  $cur-key as xs:integer ) 
{
  if (empty($rows) or ($done gt $max)) then
    ()
  else
    let $cur-row := $rows[1]
    let $email := $cur-row/Email/text()
    let $email-key := normalize-space(lower-case($email))
    return
      if (fn:collection($globals:persons-uri)//Person/Id[. = $cur-key]) then (
        <li>Skip creation of { $email } at { $cur-key } because a person with that key already exists</li>,
        local:import-iter($action, $rows, $max, $done, $cur-key + 1)
        ) 
      else if (collection($globals:persons-uri)//Person//Email[normalize-space(lower-case(.)) = $email-key]) then (
        <li>Skip creation of { $email } at { $cur-key } because a person with that email already exists</li>,
        local:import-iter($action, subsequence($rows, 2), $max, $done, $cur-key)
        )
      else if ($action = 'dry') then (
        <li>Dry creation of { $email } at { $cur-key }</li>,
        local:import-iter($action, subsequence($rows, 2), $max, $done + 1, $cur-key + 1)
        )
      else (
        let $person := local:gen-person-with-role($cur-row, string($cur-key), $local:role)
        (: TODO: add Logs history :)
        let $stored := person:create($cur-key, $person/*[local-name(.) ne 'Id'])
        return
          <li>Created { $email } at { $cur-key } inside "{ $stored }"</li>,
        local:import-iter($action, subsequence($rows, 2), $max, $done + 1, $cur-key + 1)
        )
};

let $batch-uri := request:get-parameter('batch', ())
let $tmp := request:get-parameter('max', ())
let $max := if ($tmp) then number($tmp) else ()
let $action := request:get-parameter('action', 'dry')
let $from := xs:integer(request:get-parameter('from', 1))
let $id := request:get-parameter('id', ())
return
  if ($batch-uri) then
    let $start-key := 
      (: Supposes no one else has access at same time to create persons :)
      (: FIXME: to be aligned with the way it is done in person.xqm :)
      if (fn:collection($globals:persons-uri)//Person/Id) then
        max(
          for $key in fn:collection($globals:persons-uri)//Person/Id
          return if ($key castable as xs:integer) then number($key) else 0
          ) + 1
      else
        1
    return
      if ($action = 'patch') then (: simulation :)
        <Persons>
          {
          for $row at $i in fn:doc(concat('/db/batch/', $batch-uri))//row
          let $key := $start-key + $i - 1
          (:let $person := local:gen-person-with-role($row, string($key), $local:role):)
          where not($max) or ($i <= $max)
          return local:gen-person-with-role($row, string($key), $local:role)
          }
        </Persons>
      else if ($action = 'assert') then
        <ul>
          {
          for $row in fn:doc(concat('/db/batch/', $batch-uri))//row
          let $email := $row/Email/text()
          let $email-key := normalize-space(lower-case($email))
          where collection($globals:persons-uri)//Person//Email[normalize-space(lower-case(.)) = $email-key]
          return
            <li>Skip creation of { $row/Email/text() } because a person with that email already exists</li>
          }
        </ul>
      else (
        util:declare-option("exist:serialize", "method=html5 media-type=text/html encoding=utf-8 indent=yes"),
        <html><style>p{{margin:0}}</style><body>
          <ul>
            { local:import-iter($action, subsequence(fn:doc(concat('/db/batch/', $batch-uri))//row, $from), $max, 0, $start-key) }
          </ul>
        </body></html>
        )
  else
    <p>Syntax: give the name of the coaches to import as a <i>batch</i> parameter and specifies an <i>action</i></p>
