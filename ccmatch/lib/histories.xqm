xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Support for managing a histories collection of digests by category

   Data Model:

   Histories
     Category @Name (*)
       Digest (*)
         Entry (*)
         error (?)

   July 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace histories = "http://oppidoc.com/ns/histories";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "util.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../oppidum/lib/compat.xqm";

(: ======================================================================
   Returns a resource name to store a new digest for a given category
   in the histories collection. Does sharding.
   ====================================================================== 
:)
declare function local:gen-archive-name ( $category as xs:string, $date as xs:dateTime ) as xs:string {
  let $filename := concat(substring(string($date), 1, 7), '.xml')
  return $filename
};

(: ======================================================================
   Archives a digest of the entries for a given category 
   Returns a digest copy
   Note that entries may be any element including Oppidum errors
   ====================================================================== 
:)
declare function histories:archive-all ( $category as xs:string, $entries as element()* ) as element() {
  let $date := current-dateTime()
  let $filename := local:gen-archive-name($category, $date)
  return
    <Digest Timestamp="{ $date }">
      {
      if (xdb:collection-available($globals:histories-uri)) then
        let $digest := <Digest Timestamp="{ $date }">{ $entries }</Digest>
        let $host-bucket := fn:doc(concat($globals:histories-uri, '/', $filename))/Histories
        return
          let $host-category := $host-bucket/Category[@Name eq category]
          return
            if ($host-category) then (
              update insert $digest into $host-category,
              attribute { 'Success' } { concat("New ", $category, " digest archive recorded on ", $date) }
              )
            else if ($host-bucket) then (
              (: creates host category :)
              update insert <Category Name="{ $category }">{ $digest }</Category> into $host-bucket,
              attribute { 'Success' } { concat("New ", $category, " digest archive recorded on ", $date) }
              )
            else 
              (: creates host resource bucket :)
              let $archive := <Histories><Category Name="{ $category }">{ $digest }</Category></Histories>
              let $stored-path := xdb:store($globals:histories-uri, $filename, $archive)
              return
                if(not($stored-path eq ())) then (: success :)
                  (
                  if ((xdb:get-group($globals:histories-uri, $filename) ne 'users')
                      or (xdb:get-owner($globals:histories-uri, $filename) ne 'admin')) then
                    compat:set-owner-group-permissions(concat($globals:histories-uri, '/', $filename), 'admin', 'users', 'rwxrwx---')
                  else
                    (),
                  attribute { 'Success' } { concat("New ", $category, " digest archive recorded on ", $date) }
                  )
                else
                  attribute { 'Warn' } { concat("Failed to record ", $category, " digest into ", $globals:histories-uri, '/',  $filename) }
      else
        attribute { 'Warn' } { concat("Collection ", $globals:histories-uri, " unavailable to record ", $category, " digest") },
      $entries
      }
    </Digest>
};
