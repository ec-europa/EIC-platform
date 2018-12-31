xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC XQuery Content Management Framework

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Validation utilities

   April 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace check = "http://oppidoc.com/ns/cctracker/check";

(: ======================================================================
   Returns true() if $mail is a valid e-mail address
   ======================================================================
:)
declare function check:is-email ( $mail as xs:string? ) as xs:boolean {
  let $m := normalize-space($mail)
  return
    ($m ne '') and matches($m, '^\w([\-_\.]?\w)*@\w([\-_\.]?\w)+\.[a-z]{2,}$')
};
