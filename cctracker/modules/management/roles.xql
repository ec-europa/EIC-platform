xquery version "1.0";
(: ------------------------------------------------------------------
   EIC coaching application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   User account management

   March 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns the list of users grouped by role 
   ======================================================================
:)
declare function local:gen-roles-for-viewing() as element()* {
  <Roles>
  {
  for $f in fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang='en']/Functions/Function
  return
    <Role Name="{string($f/Name)}">
    {
    string-join(
      for $p in fn:collection($globals:persons-uri)//Person/UserProfile/Roles/Role/FunctionRef[. eq $f/Id]
      let $n := $p/ancestor::Person/Name
      return concat($n/FirstName, ' ', $n/LastName),
      ', '
    )
    }
    </Role>
  }
  </Roles>
};

local:gen-roles-for-viewing()
