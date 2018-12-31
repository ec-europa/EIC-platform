xquery version "1.0";
(: --------------------------------------
   POLL - EIC Poll Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Global variables or utility functions for the application

   July 2013 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace globals = "http://oppidoc.com/oppidum/globals";

declare variable $globals:questionnaires-uri := '/db/sites/poll/questionnaires';
declare variable $globals:forms-uri := '/db/sites/poll/forms';
declare variable $globals:services-uri := '/db/www/poll/config/services.xml';
declare variable $globals:settings-uri := '/db/www/poll/config/settings.xml';
