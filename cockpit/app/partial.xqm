xquery version "1.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   This module can be used to declare functions using XPath expressions 
   with no namespace to be called from epilogue.xql, since that later one 
   is in the default XHTML namespace.

   November 2016 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace partial = "http://oppidoc.com/oppidum/partial";

declare function partial:/cockpit () {
  <Scaffold/>
};

