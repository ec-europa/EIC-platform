xquery version "3.1";
(: --------------------------------------
   Generate model for ZIP archive generation of an event 
   submitted logos and photos in the Confirmation form

   NOTE: should be mapped to a POST method to avoid end users
   bookmarking and sendig too much requests (since ZIP archive
   generation in epilogue is a memory costly operation)
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";
declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace resources = "http://oppidoc.com/oppidum/resources";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:enterprises := globals:collection('enterprises-uri');
declare variable $local:events := globals:collection('events-uri');

declare function local:get-bucket-name( $id as xs:string ) as xs:string {
  concat(
    string-join( for $a in (1 to 4 - (fn:string-length($id))) return "0", '') ,
    $id
  )
};

(: ======================================================================
   Temporary hacked version while we fix bug on binary resources mess
   when SME confirms several events...
   ====================================================================== 
:)
declare function local:resources(
  $event-def as element()
) as element()
{
  let $rankings := $event-def/Rankings[@Iteration eq 'cur']
  return
    <Resources>
    {
      if (exists($rankings/Confirmed)) then
        for $applicant in $event-def/FinalRankings[@Iteration eq 'cur']/Lists/(MainList|ReserveList)/Applicant
        let $evn-match := $local:enterprises//Enterprise[Id = $applicant/EnterpriseRef]//Events/Event[Id = $event-def/Id]
        let $id := $evn-match/../../Id
        let $resource-files := distinct-values($evn-match//Resource)
        let $binary-files := $local:enterprises//Enterprise[Id = $applicant/EnterpriseRef]/Binaries/Binary[. = $resource-files]
        return
          (:for $resource in $evn-match//ResourceId:)
          (:let $binary := $local:enterprises//Enterprise[Id = $applicant/EnterpriseRef]/Binaries/Binary[@Id eq $resource]:)
          for $binary in $binary-files
          let $key := concat(replace($binary, '\.', '-'), '-', $binary/@Filename)
          group by $key
          return
            let $pivot-binary := fn:head($binary)
              let $entry :=
              (
              <entry>
              {
              let $folder-name := $local:enterprises//Enterprise[Id = $id]//ShortName/text()
              return 
              attribute name { string-join(($folder-name, if (count($binary-files[@Filename = $pivot-binary/@Filename]) > 1) then $key else $pivot-binary/@Filename), '/') },
              let $folder := fn:floor($id div 50)
              let $find-folder := local:get-bucket-name( $folder )
              return
                (:attribute path { concat('/db/binaries/cockpit/enterprises/',$find-folder,'/', $id,'/', $binary/text() ) }:)
                attribute path { string-join(('/db/binaries/cockpit/enterprises', $find-folder, $id, $pivot-binary), '/') }
              }
              </entry>
              )
            return $entry
      else
        ()
    }  
    </Resources>
};

let $cmd := oppidum:get-command()
let $trail := $cmd/@trail
let $event-id := tokenize($trail,'/')[2]
let $event-def := fn:collection($globals:events-uri)//Event[Id eq $event-id]
return 
  (: access control, ranking implies right to export ZIP :)
  if (access:check-entity-permissions('rank', 'Events', (), $event-def)) then
    <site:view>
      <site:resources>{local:resources( $event-def )}</site:resources>
    </site:view>
  else
    oppidum:throw-error('FORBIDDEN', ())
    