xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Statistical filtering for diagrams view

   January 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

let $cmd := oppidum:get-command()
let $filter-spec-uri := oppidum:path-to-config('stats.xml')
let $target := string($cmd/resource/@name)
let $user := oppidum:get-current-user()
return
  if (doc-available($filter-spec-uri)) then (
    if (oppidum:get-current-user-groups() = ('business-intelligence')) then (: FIXME: replace with oppidum:get-current-user-groups :)
      oppidum:throw-message('INFO-BI', ())
    else if (oppidum:get-current-user-groups() = ('region-manager')) then (: FIXME: replace with oppidum:get-current-user-groups :)
      let $regions := access:get-current-user-regions-as('region-manager')
      return
        oppidum:throw-message('INFO-KAMCO', display:gen-name-for-regional-entities( $regions, 'en'))
    else if (oppidum:get-current-user-groups() = ('ncp')) then (: FIXME: replace with oppidum:get-current-user-groups :)
      let $nuts := access:get-current-user-nuts-as('ncp')
      return
        oppidum:throw-message('INFO-NCP', string-join($nuts, ', '))
    else if (oppidum:get-current-user-groups() = ('kam')) then (: FIXME: replace with oppidum:get-current-user-groups :)
      oppidum:throw-message('INFO-KAM', ())
    else (: should be omniscient user per-construction :)
      (),
    <Stats>
      <Window>Statistics for {$target}</Window>-
      {
      let $forms := fn:doc($filter-spec-uri)/Statistics/Filters/Filter[@Page = $target]/Formular
      return
        <Formular Id="editor">
          {
          $forms/*[local-name(.) ne 'Command'],
          <Commands>
            {
            for $c in $forms/Command
            return
              if ($c/@Allow) then (: access control :)
                <Command>
                  {
                  if (access:check-rule(string($c/@Allow))) then
                    ()
                  else
                    attribute Access { 'disabled' },
                  $c/(@* | text())
                  }
                </Command>
              else
                $c
            }
          </Commands>
          }
        </Formular>,
      fn:doc($filter-spec-uri)/Statistics/Filters/Filter[@Page = $target]/*[local-name(.) ne 'Formular']
      }
    </Stats>)[last()]
  else
    oppidum:throw-error('DB-NOT-FOUND', 'stats.xml')
