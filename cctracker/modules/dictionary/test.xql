xquery version "1.0";
(: --------------------------------------
   Localization Test Tool

   Author: Stéphane Sire <s.sire@oppidoc.fr>

   Utility script to check missing dictionary entries.

   September 2013 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=html5 media-type=text/html";

let $fr-dico := fn:doc('/db/www/cctracker/config/dictionary.xml')/site:Dictionary/site:Translations[@lang = 'fr']
let $de-dico := fn:doc('/db/www/cctracker/config/dictionary.xml')/site:Dictionary/site:Translations[@lang = 'de']
return
  <html>
    <head>
      <title>Test du dictionnaire</title>
    </head>
    <body>
      <h1>Clefs manquantes</h1>
      <p>Les recherches sont fondées sur les <tt>@loc</tt> de la collection <tt>/db/www/cctracker</tt>. Pour obtenir un bon diagnostique installez l'application dans la BD.</p>
      <p>Les erreurs sont à corriger dans le fichier de configuration <tt>config/dictionary.xml</tt> et sa version dans la BD.</p>
      <h2>Dictionnaire Français</h2>
      <ul>
      {
        for $loc in distinct-values(fn:collection('/db/www/cctracker')//@loc)
        where empty($fr-dico/site:Translation[@key = $loc])
        order by $loc
        return 
          <li>{$loc}</li>
      }
      </ul>
      <h2>Dictionnaire Allemand</h2>
      <ul>
      {
        for $loc in distinct-values(fn:collection('/db/www/cctracker')//@loc)
        where empty($de-dico/site:Translation[@key = $loc])
        order by $loc
        return 
          <li>{$loc}</li>
      }
      </ul>
    </body>
  </html>
