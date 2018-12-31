xquery version "1.0";
(: --------------------------------------
   EIC Case Tracker application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Global variables or utility functions for the application

   July 2013 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace globals = "http://oppidoc.com/oppidum/globals";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";

(: Application name (rest), project folder name and application collection name :)
declare variable $globals:app-name := 'cctracker';
declare variable $globals:app-folder := 'projects';
declare variable $globals:app-collection := 'cctracker';

(: Database paths :)
declare variable $globals:application-uri := '/db/www/cctracker/config/application.xml';
declare variable $globals:database-uri := '/db/www/cctracker/config/database.xml';
declare variable $globals:global-information-uri := '/db/sites/cctracker/global-information/global-information.xml'; (: DEPRECATED :)
declare variable $globals:dico-uri := '/db/www/cctracker/config/dictionary.xml';
declare variable $globals:cache-uri := '/db/caches/cctracker/cache.xml';
declare variable $globals:global-info-uri := '/db/sites/cctracker/global-information';
declare variable $globals:settings-uri := '/db/www/cctracker/config/settings.xml';
declare variable $globals:log-file-uri := '/db/debug/login.xml';
declare variable $globals:services-uri := '/db/www/cctracker/config/services.xml';
declare variable $globals:stats-uri := '/db/www/cctracker/config/stats.xml';
declare variable $globals:variables-uri := '/db/www/cctracker/config/variables.xml';
declare variable $globals:proxies-uri := '/db/www/cctracker/config/proxies.xml';
declare variable $globals:stats-formulars-uri := '/db/www/cctracker/formulars';
declare variable $globals:analytics-uri := '/db/analytics/cctracker/';
declare variable $globals:templates-uri := '/db/www/cctracker/templates';

(: Application entities paths :)
declare variable $globals:regions-uri := '/db/sites/cctracker/regions';
declare variable $globals:persons-uri := '/db/sites/cctracker/persons';
declare variable $globals:remotes-uri := '/db/sites/cctracker/persons/remotes.xml';
declare variable $globals:cases-uri := '/db/sites/cctracker/cases';
declare variable $globals:projects-uri := '/db/sites/cctracker/projects';
declare variable $globals:enterprises-uri := '/db/sites/cctracker/enterprises/enterprises.xml';
declare variable $globals:reminders-uri := '/db/sites/cctracker/reminders';
declare variable $globals:timesheets-uri := '/db/sites/cctracker/timesheets';
declare variable $globals:checks-uri := '/db/sites/cctracker/checks';
declare variable $globals:checks-config-uri := '/db/www/cctracker/config/checks.xml';
declare variable $globals:reports-uri := '/db/sites/cctracker/reports';

(: this variable MUST be the same as in EXCM lib/globals.xqm :)
declare variable $globals:globals-uri := '/db/www/excm/config/globals.xml';

declare function globals:app-name() as xs:string {
  $globals:app-name
};

declare function globals:app-folder() as xs:string {
  $globals:app-folder
};

declare function globals:app-collection() as xs:string {
  $globals:app-collection
};

(: ******************************************************************* :)
(:                                                                     :)
(: Below this point code copied from EXCM lib/globals.xqm              :)
(:                                                                     :)
(: ******************************************************************* :)

(:~
 : Returns the selector from global information that serves as a reference for
 : a given selector enriched with meta-data.
 : @return The normative Selector element or the empty sequence
 :)
declare function globals:get-normative-selector-for( $name ) as element()? {
  fn:collection(fn:doc($globals:globals-uri)//Global[Key eq 'global-info-uri']/Value)//Description[@Role = 'normative']/Selector[@Name eq $name]
};

declare function globals:doc-available( $name ) {
  fn:doc-available(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};

(: Robust version to support migration from file to collection storage :)
declare function globals:doc( $name ) {
  let $file-uri := fn:doc($globals:globals-uri)//Global[Key eq $name]/Value
  return
    if (ends-with($file-uri, '.xml')) then
      fn:doc($file-uri)
    else
      fn:collection($file-uri)
};

declare function globals:collection-available( $name ) {
  xdb:collection-available(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};

declare function globals:collection-uri( $name ) as xs:string? {
  let $col-uri := fn:doc($globals:globals-uri)//Global[Key eq $name]/Value/text()
  return 
    if (ends-with($col-uri, '/')) then substring($col-uri, 1, string-length($col-uri)-1) else $col-uri
};

declare function globals:collection( $name ) {
  fn:collection(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};
