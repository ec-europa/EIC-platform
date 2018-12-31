xquery version "1.0";
(: ------------------------------------------------------------------
   Coaching application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Dictionary utility

   USAGE
   - http://localhost:8080/exist/projects/cctracker/dictionary/export?m=(clean / miss / pregen)
   - clean pour générer une version propre bien indentée
   - miss pour faire apparaitre les clefs manquantes par rapport au 'fr' avec MISSING
   - pregen pour générer les clefs manquantes avec la notation "traduire [ ]" pour envoyer à traduire

   WARNING : please copy dictionary.xml into /db/www/cctracker/config/dictionary.xml before proceeding

   June 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare default element namespace "http://oppidoc.com/oppidum/site" ;

declare option exist:serialize "method=xml media-type=text/xml";

let $crlf := codepoints-to-string((13, 10))
let $mode := request:get-parameter('m', 'clean')
return
  <Dictionary>
  <Translations lang='fr'>
  {
  for $c in fn:doc('/db/www/cctracker/config/dictionary.xml')//Translations[@lang='fr']/(Translation | comment())
  return 
    if ($c instance of comment()) then
      if (starts-with(string($c),'***')) then
        ()
      else
        let $bullets := for $i in 1 to string-length($c) return "*"
        return (
          $crlf,
          $crlf,
          "       ", comment { string-join($bullets,'') }, $crlf,
          "       ", $c, $crlf,
          "       ", comment { string-join($bullets,'') }, $crlf,
          $crlf,
          "       "
          )
    else
      $c
  }
  </Translations>
  <Translations lang='de'>
  {
  for $c in fn:doc('/db/www/cctracker/config/dictionary.xml')//Translations[@lang='fr']/(Translation | comment())
  return 
    if ($c instance of comment()) then
      if (starts-with(string($c),'***')) then
        ()
      else
        let $bullets := for $i in 1 to string-length($c) return "*"
        return (
          $crlf,
          $crlf,
          "       ", comment { string-join($bullets,'') }, $crlf,
          "       ", $c, $crlf,
          "       ", comment { string-join($bullets,'') }, $crlf,
          $crlf,
          "       "
          )
    else
      let $de := fn:doc('/db/www/cctracker/config/dictionary.xml')//Translations[@lang='de']/Translation[@key eq $c/@key]
      return
        if ($de) then
          $de
        else if ($mode = 'miss') then
          <MISSING>{$c/@key}</MISSING>
        else if ($mode = 'pregen') then
          <Translation key="{$c/@key}">traduire[ {$c/text()} ]</Translation>
        else
          ()
  }
  </Translations>
  <Translations lang='en'>
  {
  for $c in fn:doc('/db/www/cctracker/config/dictionary.xml')//Translations[@lang='en']/(Translation | comment())
  return 
    if ($c instance of comment()) then
      if (starts-with(string($c),'***')) then
        ()
      else
        let $bullets := for $i in 1 to string-length($c) return "*"
        return (
          $crlf,
          $crlf,
          "       ", comment { string-join($bullets,'') }, $crlf,
          "       ", $c, $crlf,
          "       ", comment { string-join($bullets,'') }, $crlf,
          $crlf,
          "       "
          )
    else
      let $de := fn:doc('/db/www/cctracker/config/dictionary.xml')//Translations[@lang='en']/Translation[@key eq $c/@key]
      return
        if ($de) then
          $de
        else if ($mode = 'miss') then
          <MISSING>{$c/@key}</MISSING>
        else if ($mode = 'pregen') then
          <Translation key="{$c/@key}">traduire[ {$c/text()} ]</Translation>
        else
          ()
  }
  </Translations>
</Dictionary>

(:
<Special>
  {
  for $k in fn:doc('/db/www/cctracker/config/dictionary.xml')//Translations[@lang='de']/Translation
  where count(fn:doc('/db/www/cctracker/config/dictionary.xml')//Translations[@lang='fr']/Translation[@key = string($k/@key)]) = 0
  return
    $k
  }
</Special>
:)

