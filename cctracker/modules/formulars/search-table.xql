(: ======================================================================
   Transforms a <SearchMask> specification into an XQuery function
   to statically display search criterias from a submitted request
   into a plain table (non editable)

   UNFINISHED WORK (should be plugged into Supergrid UI)

   In the meantime to use it cut and paste the <SearchMask> element in the $spec
   from the formular specification to convert into XQuery table renderer code
   then copy / paste into sandbox to use it

   This has been used to generate parts of modules/stats/export.xql
   using formulars/stats-activities.xml and formulars/stats-cases.xml
   ======================================================================
:)

declare function local:gen-function ( $criteria as element() ) as xs:string {
  if ($criteria/@Tag eq 'Period') then
    concat(
      '{( if ($filter/StartDate) then concat("Du ", $filter/StartDate) else (),',
      '   if ($filter/EndDate) then concat("Au ", $filter/EndDate) else () )}'
      )
  else if ($criteria/@function) then
    concat(
      '{ ',
      'string-join(',
      'for $i in $filter//*[local-name(.) eq "', string($criteria/@ValueTag),'"] ',
      'return display:', string($criteria/@function), '($i, $lang)',
      ', ", ")',
      ' }'
    )
  else
    concat('{ string-join($filter//*[local-name(.) eq "', string($criteria/@Tag),'"], ",") }')

};

declare function local:transform($nodes as item()*) as item()* {
  for $n in $nodes
  return
    typeswitch($n)
      case element() return
        if (local-name($n) eq 'SearchMask') then
          <table id="filters">
            <caption style="font-size:24px;margin:20px 0 10px;text-align:left"><b>Critères de recherche</b></caption>
            {
            local:transform($n/*)
            }
          </table>
        else if (local-name($n) eq 'Group') then (
          <tr>
            <td style="width:25%" rowspan="{count($n/Criteria)}">{$n/Title/text()}</td>
            <td style="width:25%">{$n/Criteria[1]/text()}</td>
            <td style="width:50%">{ local:gen-function ($n/Criteria[1]) }</td>
          </tr>,
          local:transform($n/Criteria[position()>1])
          )
        else if (local-name($n) eq 'Criteria') then
          <tr>
            <td>{$n/text()}</td>
            <td>{ local:gen-function ($n) }</td>
          </tr>
        else
          ()
      default return ()
};

let $spec := <SearchMask/>
return
  local:transform($spec)
