xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Statistical filtering for diagrams view

   See also stats.xsl

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
  if (doc-available($filter-spec-uri)) then
    (: throw messages here if form.xql narrows down search scope depending on user's role :)
    <Stats>
      { 
      if (request:get-parameter('m', ()) eq 'embed') then 
        attribute { 'Embedded' } { 'on'}
      else
        ()
      }
      <Window>Statistics for {$target}</Window>
      <Defaults>
        <Layout>
          <Width>750</Width>
        </Layout>
      </Defaults>
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
                  (: rewrite URL with base-url because of embedded mode :)
                  attribute { 'base-url' } { 'stats/' },
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
        <SpinningWheel Id="cm-stats-busy"/>,
      fn:doc($filter-spec-uri)/Statistics/Filters/Filter[@Page = $target]/*[local-name(.) ne 'Formular']
      }
    </Stats>
  else
    oppidum:throw-error('DB-NOT-FOUND', 'stats.xml')
