xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Global variables or utility functions for the application

   Sept 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace globals = "http://oppidoc.com/oppidum/globals";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";

(: Application name (rest), project folder name and application collection name :)
declare variable $globals:app-name := 'ccmatch';
declare variable $globals:app-folder := 'projects';
declare variable $globals:app-collection := 'ccmatch';

(: Database paths :)
declare variable $globals:application-uri := '/db/www/ccmatch/config/application.xml';
declare variable $globals:persons-uri := '/db/sites/ccmatch/persons';
declare variable $globals:remotes-uri := '/db/sites/ccmatch/persons/remotes.xml';
declare variable $globals:dico-uri := '/db/www/ccmatch/config/dictionary.xml';
declare variable $globals:cache-uri := '/db/caches/ccmatch/cache.xml';
declare variable $globals:global-info-uri := '/db/sites/ccmatch/global-information';
declare variable $globals:settings-uri := '/db/www/ccmatch/config/settings.xml';
declare variable $globals:log-file-uri := '/db/debug/login.xml';
declare variable $globals:services-uri := '/db/www/ccmatch/config/services.xml';
declare variable $globals:persons-cv-uri := '/db/sites/ccmatch/cv';
declare variable $globals:persons-photo-uri := '/db/sites/ccmatch/photos';
declare variable $globals:hosts-uri := '/db/sites/ccmatch/hosts';
declare variable $globals:histories-uri := '/db/sites/ccmatch/histories';
declare variable $globals:feeds-uri := '/db/www/ccmatch/config/feeds.xml';
declare variable $globals:nonce-uri := '/db/nonces/nonces.xml';
declare variable $globals:analytics-uri := '/db/analytics/ccmatch';
declare variable $globals:tasks-uri := '/db/tasks/ccmatch/community.xml';
declare variable $globals:templates-uri := '/db/www/ccmatch/templates';

(: MUST be aligned with xcm/lib/globals.xqm :)
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
(: Below this point copy content to your application's lib/globals.xqm :)
(:                                                                     :)
(: ******************************************************************* :)

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
