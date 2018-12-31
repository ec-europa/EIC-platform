xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   DEPRECATED: Please do not use
   
   Utility to generate global information concerning EEN regions records
   from Excel tables converted to XML, the result must be cut-and-pasted
   into regions collection

   Used once to initialize the list of regions which is then directly 
   editable from within the application

   Not required for normal operations

   LIMITATION
   - first version to be used with cut-and-paste and sandbox

   February 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:global-info-uri := '/db/sites/cctracker/global-information';
declare variable $local:input := '/db/batch/regions-2015-02-10.xml';
declare variable $local:first := 1000;

(: Checks new region labels introduction :)
(: let $acro := distinct-values(fn:doc('/db/batch/regions-2015-03-09.xml')//row/Region/text())
return 
  <Check>
   {
  for $a in $acro
  return 
     if (fn:doc('/db/sites/cctracker/global-information/regions.xml')//Option[Region eq normalize-space($a)]) then 
       ()
     else
       <Missing>{ $a } ===> { fn:doc('/db/batch/regions-2015-03-09.xml')//row[Region eq $a][1]/Acronym/text() } </Missing>
   }
  </Check>:)

(: Checks update to KAM Coordinators list :)
(:  let $mail := distinct-values(fn:doc('/db/batch/regions-2015-03-09.xml')//row/Email/text())
  return 
    <Check>
     {
    for $m in $mail
    let $person := fn:doc('/db/batch/regions-2015-03-09.xml')//row[Email eq $m][1]
    let $acro := normalize-space(fn:doc('/db/batch/regions-2015-03-09.xml')//row[Email eq $m][1]/Acronym/text())
    let $region := fn:doc('/db/sites/cctracker/global-information/regions.xml')//Option[Acronym eq $acro]/Id/text()
    let $cur-coordinator := fn:collection('/db/sites/cctracker/persons')//Person[UserProfile/Roles/Role[(FunctionRef eq '3') and (RegionalEntityRef eq $region)]]
    let $existing := fn:collection('/db/sites/cctracker/persons')//Person[Contacts/Email eq $m]
    return 
       if ($cur-coordinator/Contacts/Email = $m) then
         <Same>{ $m } ===> { $acro } </Same>
       else
         <Missing>{ concat($person/FirstName, ' ', $person/Surname, ' (', $m, ')') } { if (not($existing)) then '[NEW]' else () } ===> { $acro } replaces { concat($cur-coordinator/Name/FirstName, ' ', $cur-coordinator/Name/LastName, ' (', $cur-coordinator/Contacts/Email/text(), ')') } </Missing>
     }
    </Check>:)


(: ======================================================================
   Converts an EC full Excel country name into a database Country code
   ======================================================================
:)
declare function local:gen-country-for( $country as element()? ) as element()? {
  if ($country/text()) then
    fn:collection($local:global-info-uri)/GlobalInformation/Description[@Lang = 'en']//Selector[@Name eq 'Countries']/Option[CountryName eq normalize-space($country/text())]
  else
    ()
};

declare function local:gen-region( $row as element(), $id as xs:string ) as element() {
  let $acro := replace($row/Acronym, '&amp;', concat('&amp;', 'amp;'))
  let $country := local:gen-country-for($row/Country)
  let $region := $row/Region[. ne '']
  let $label := 
    if ($country) then
      concat($acro, '::', $country/CountryName/text())
    else
      $acro
  return 
    <Option>{(
      <Id>{$id}</Id>,
      <Acronym>{ normalize-space($acro) }</Acronym>,
      <Label>{ $label }</Label>,
      <LongLabel>
        {
        if ($region) then
          concat($label, ' (', $region, ')')
        else
          $label
        }
      </LongLabel>,
      <Country>{ if ($country) then $country/CountryCode/text() else 'MISSING' }</Country>,
      let $nuts := $row/*[starts-with(local-name(), 'nuts')][. ne '']
      return
        if ($nuts) then
          <NutsCodes>
            {
            for $n in $nuts
            return <Nuts>{ $n/text() }</Nuts>
            }
          </NutsCodes>
        else
          (),
      $region
    )}</Option>
};

let $keys := distinct-values(fn:doc($local:input)//row/Acronym/text())
return (: to be stored inside global-information/regions.xml :)
  <GlobalInformation>
    <Description Lang="en">
      <Selector Name="RegionalEntities" Value="Id" Label="Label" Test="EEN Entities">
      {
      for $key at $i in $keys[position() < ($local:first + 1)]
      let $row := fn:doc($local:input)//row[Acronym eq $key][1]
      return
        local:gen-region($row, string($i))
      }
      </Selector>
    </Description>
  </GlobalInformation>
