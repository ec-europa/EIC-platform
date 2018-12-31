xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Global variables or utility functions for the application

   Customize this file for your application

   November 2016 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace globals = "http://oppidoc.com/ns/xcm/globals";

(: Application name (rest), project folder name and application collection name :)
declare variable $globals:app-name := 'cockpit';
declare variable $globals:app-folder := 'projects';
declare variable $globals:app-collection := 'cockpit';

(: Database paths :)
declare variable $globals:dico-uri := '/db/www/cockpit/config/dictionary.xml';
declare variable $globals:cache-uri := '/db/caches/cockpit/cache.xml';
declare variable $globals:global-info-uri := '/db/sites/cockpit/global-information';
declare variable $globals:settings-uri := '/db/www/cockpit/config/settings.xml';
declare variable $globals:log-file-uri := '/db/debug/login.xml';
declare variable $globals:application-uri := '/db/www/cockpit/config/application.xml';
declare variable $globals:templates-uri := '/db/www/cockpit/templates';
declare variable $globals:variables-uri := '/db/www/cockpit/config/variables.xml';
declare variable $globals:stats-formulars-uri := '/db/www/cockpit/formulars';
declare variable $globals:database-file-uri := '/db/www/cockpit/config/database.xml';
declare variable $globals:services-uri := '/db/www/cockpit/config/services.xml';
declare variable $globals:feedbacks-uri := '/db/sites/cockpit/feedbacks';

(: Application entities paths :)
declare variable $globals:remotes-uri := (); (: TO BE DEFINED: pre-registration ? :)
declare variable $globals:persons-uri := '/db/sites/cockpit/persons';
declare variable $globals:enterprises-uri := '/db/sites/cockpit/enterprises';
declare variable $globals:admissions-uri := '/db/sites/cockpit/admissions';
declare variable $globals:tasks-uri := '/db/tasks/cockpit/community.xml';
declare variable $globals:events-uri := '/db/sites/cockpit/events';
declare variable $globals:binaries-uri := '/db/binaries/cockpit';

(: MUST be aligned with xcm/lib/globals.xqm :)
declare variable $globals:xcm-name := 'xcm';
declare variable $globals:globals-uri := '/db/www/xcm/config/globals.xml';

declare function globals:app-name() as xs:string {
  $globals:app-name
};

declare function globals:app-folder() as xs:string {
  $globals:app-folder
};

declare function globals:app-collection() as xs:string {
  $globals:app-collection
};

(:~
 : Returns the selector from global information that serves as a reference for
 : a given selector enriched with meta-data.
 : @return The normative Selector element or the empty sequence
 :)
declare function globals:get-normative-selector-for( $name ) as element()? {
  fn:collection($globals:global-info-uri)//Description[@Role = 'normative']/Selector[@Name eq $name]
};

(: ******************************************************* :)
(:                                                         :)
(: Below this point paste content from xcm/lib/globals.xqm :)
(:                                                         :)
(: ******************************************************* :)

declare function globals:doc-available( $name ) {
  fn:doc-available(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};

declare function globals:collection( $name ) {
  fn:collection(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};

declare function globals:doc( $name ) {
  fn:doc(fn:doc($globals:globals-uri)//Global[Key eq $name]/Value)
};
