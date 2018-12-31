xquery version "1.0";
(: ------------------------------------------------------------------
   Coaching application migration screen

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Use it to set a curtain in controller.xql while migrating the server to a new infrastructure

   June 2014 - European Union Public Licence EUPL
   
   POUR ACTIVER CETTE PAGE COPIER LE BLOC SUIVANT A LA FIN DU FICHIER controller.xql de l'application :
   
   declare variable $curtain := <site startref="stage" supported="login" db="/db/www/coaching" confbase="/db/www/coaching" key="coaching" mode="prod">
      <item name="*">
        <model src="models/migration.xql"/>
      </item>
   </site>;

   let $mapping := fn:doc('/db/www/coaching/config/mapping.xml')/site
   let $lang := local:localize($exist:path, string($mapping/@languages), string($mapping/@default))
   return 
     if ($curtain and (xdb:get-current-user() != 'admin')) then 
       gen:process($exist:root, $exist:prefix, $exist:controller, $exist:path, $lang, true(), $access, $actions, $curtain)
     else
       gen:process($exist:root, $exist:prefix, $exist:controller, $exist:path, $lang, true(), $access, $actions, $mapping)   
   ------------------------------------------------------------------ :)

declare option exist:serialize "method=html media-type=text/html";
<html>
  <style type="text/css" media="screen">
h1 {{
  text-align: center;
}}  
body {{
  margin: 2em auto ;
  width: 400px;
}}
body p {{
  text-align: center;
}}
  </style>
  <body>
    <h1>Changement de serveur</h1>
    <p>L'application a déménagé sur un nouveau serveur.</p>
    <p>Il se peut que pendant le délai de mise à jour des serveurs de nom (jusqu'à 48H) vous atterrissiez sur cette page. Dans l'intervalle vous pouvez accéder au nouveau serveur en suivant ce <a href="https://185.50.191.254/stage">lien</a>.</p>
    <p>Notez que le nouveau serveur utilise une connexion sécurisée, vous devrez donc accepter son certificat.</p>
    <p>Merci de votre compréhension.</p>
  </body>
</html>
